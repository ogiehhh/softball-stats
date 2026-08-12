-- Live offensive scoring remains event-sourced: the plate appearance stores the credited
-- result while runner_advancements stores every runner's actual end location. The mutable
-- game_states row is locked and updated as a small resume snapshot.

alter table public.games
alter column team_score set default 0;

-- Existing in-progress games predate synchronized team scores. Rebuild them from run events.
update public.games as game
set team_score = (
  select count(*)::smallint
  from public.runner_advancements as advancement
  join public.plate_appearances as appearance
    on appearance.id = advancement.plate_appearance_id
  where appearance.game_id = game.id
    and advancement.ending_base = 'home'
)
where game.status = 'in_progress';

-- New games should visibly begin at 0 runs.
create or replace function public.create_game_with_lineup(
  p_league_id uuid,
  p_season_id uuid,
  p_opponent text,
  p_played_at timestamptz,
  p_lineup_player_ids uuid[]
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  created_game_id uuid;
  lineup_count integer;
  rostered_count integer;
begin
  if caller_id is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication is required to start a game.';
  end if;

  if not exists (
    select 1
    from public.admin_users
    where user_id = caller_id
  ) then
    raise exception using
      errcode = '42501',
      message = 'Admin authorization is required to start a game.';
  end if;

  if p_league_id is null or p_season_id is null then
    raise exception using
      errcode = '22023',
      message = 'A league and season are required.';
  end if;

  if not exists (
    select 1
    from public.seasons as season
    join public.leagues as league on league.id = season.league_id
    where season.id = p_season_id
      and season.league_id = p_league_id
      and season.active
      and league.active
  ) then
    raise exception using
      errcode = '22023',
      message = 'The selected active season does not belong to the selected active league.';
  end if;

  if p_opponent is null or btrim(p_opponent) = '' then
    raise exception using
      errcode = '22023',
      message = 'An opponent name is required.';
  end if;

  if p_played_at is null then
    raise exception using
      errcode = '22023',
      message = 'A game date is required.';
  end if;

  lineup_count := coalesce(cardinality(p_lineup_player_ids), 0);

  if lineup_count = 0 then
    raise exception using
      errcode = '22023',
      message = 'The lineup must contain at least one rostered player.';
  end if;

  if exists (
    select 1
    from unnest(p_lineup_player_ids) as lineup(player_id)
    group by player_id
    having player_id is null or count(*) > 1
  ) then
    raise exception using
      errcode = '22023',
      message = 'The lineup cannot contain blank or duplicate players.';
  end if;

  select count(*)::integer
  into rostered_count
  from unnest(p_lineup_player_ids) as lineup(player_id)
  join public.season_players as season_player
    on season_player.season_id = p_season_id
    and season_player.player_id = lineup.player_id;

  if rostered_count <> lineup_count then
    raise exception using
      errcode = '22023',
      message = 'Every lineup player must belong to the selected season roster.';
  end if;

  insert into public.games (
    season_id,
    played_at,
    opponent,
    status,
    team_score
  )
  values (
    p_season_id,
    p_played_at,
    btrim(p_opponent),
    'in_progress',
    0
  )
  returning id into created_game_id;

  insert into public.game_lineup (
    game_id,
    season_id,
    player_id,
    batting_order
  )
  select
    created_game_id,
    p_season_id,
    lineup.player_id,
    lineup.batting_order::smallint
  from unnest(p_lineup_player_ids) with ordinality
    as lineup(player_id, batting_order);

  insert into public.game_states (
    game_id,
    inning,
    outs,
    next_batter_order,
    first_base_player_id,
    second_base_player_id,
    third_base_player_id
  )
  values (
    created_game_id,
    1,
    0,
    1,
    null,
    null,
    null
  );

  return created_game_id;
end;
$$;

-- One call records the credited result, complete runner movement history, runs/RBI,
-- inning transition, next batter, base occupancy, and synchronized team score.
create or replace function public.record_plate_appearance(
  p_game_id uuid,
  p_result public.plate_appearance_result,
  p_outs_recorded smallint,
  p_rbi smallint,
  p_runner_outcomes jsonb,
  p_expected_state_updated_at timestamptz
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  locked_game public.games%rowtype;
  locked_state public.game_states%rowtype;
  current_batter_id uuid;
  resolved_next_batter_order smallint;
  created_appearance_id uuid;
  next_sequence integer;
  expected_movement_count integer;
  movement_count integer;
  distinct_player_count integer;
  distinct_start_count integer;
  out_count integer;
  run_count integer;
  batter_destination public.base_destination;
  next_first_base_player_id uuid;
  next_second_base_player_id uuid;
  next_third_base_player_id uuid;
begin
  if caller_id is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication is required to record a play.';
  end if;

  if not exists (
    select 1 from public.admin_users where user_id = caller_id
  ) then
    raise exception using
      errcode = '42501',
      message = 'Admin authorization is required to record a play.';
  end if;

  -- Every scoring mutation acquires locks in game -> state order and holds them only
  -- for this short database transaction.
  select *
  into locked_game
  from public.games
  where id = p_game_id
  for update;

  if not found then
    raise exception using
      errcode = '22023',
      message = 'Game not found.';
  end if;

  select *
  into locked_state
  from public.game_states
  where game_id = p_game_id
  for update;

  if not found then
    raise exception using
      errcode = '22023',
      message = 'Game state not found.';
  end if;

  if locked_game.status <> 'in_progress' then
    raise exception using
      errcode = '22023',
      message = 'Only an in-progress game can be scored.';
  end if;

  if p_expected_state_updated_at is null
    or locked_state.updated_at <> p_expected_state_updated_at
  then
    raise exception using
      errcode = '40001',
      message = 'The game state changed. Refresh before recording this play.';
  end if;

  select player_id
  into current_batter_id
  from public.game_lineup
  where game_id = p_game_id
    and batting_order = locked_state.next_batter_order;

  if current_batter_id is null then
    raise exception using
      errcode = '22023',
      message = 'The current batting-order position has no lineup player.';
  end if;

  select coalesce(
    min(batting_order) filter (where batting_order > locked_state.next_batter_order),
    min(batting_order)
  )::smallint
  into resolved_next_batter_order
  from public.game_lineup
  where game_id = p_game_id;

  if p_result is null then
    raise exception using
      errcode = '22023',
      message = 'A plate-appearance result is required.';
  end if;

  if p_runner_outcomes is null or jsonb_typeof(p_runner_outcomes) <> 'array' then
    raise exception using
      errcode = '22023',
      message = 'Runner outcomes must be a complete array.';
  end if;

  expected_movement_count := 1
    + case when locked_state.first_base_player_id is null then 0 else 1 end
    + case when locked_state.second_base_player_id is null then 0 else 1 end
    + case when locked_state.third_base_player_id is null then 0 else 1 end;

  select
    count(*)::integer,
    count(distinct movement.player_id)::integer,
    count(distinct movement.starting_base)::integer,
    count(*) filter (where movement.ending_base = 'out')::integer,
    count(*) filter (where movement.ending_base = 'home')::integer
  into
    movement_count,
    distinct_player_count,
    distinct_start_count,
    out_count,
    run_count
  from jsonb_to_recordset(p_runner_outcomes) as movement(
    player_id uuid,
    starting_base public.base_origin,
    ending_base public.base_destination
  );

  if movement_count <> expected_movement_count
    or distinct_player_count <> movement_count
    or distinct_start_count <> movement_count
  then
    raise exception using
      errcode = '22023',
      message = 'Every runner and the batter must have exactly one outcome.';
  end if;

  if exists (
    select 1
    from jsonb_to_recordset(p_runner_outcomes) as movement(
      player_id uuid,
      starting_base public.base_origin,
      ending_base public.base_destination
    )
    where movement.player_id is null
      or movement.starting_base is null
      or movement.ending_base is null
      or movement.player_id is distinct from case movement.starting_base
        when 'batter' then current_batter_id
        when 'first' then locked_state.first_base_player_id
        when 'second' then locked_state.second_base_player_id
        when 'third' then locked_state.third_base_player_id
      end
  ) then
    raise exception using
      errcode = '22023',
      message = 'Submitted runner outcomes do not match the current game state.';
  end if;

  if exists (
    select 1
    from jsonb_to_recordset(p_runner_outcomes) as movement(
      player_id uuid,
      starting_base public.base_origin,
      ending_base public.base_destination
    )
    where (movement.starting_base = 'second' and movement.ending_base = 'first')
      or (
        movement.starting_base = 'third'
        and movement.ending_base in ('first', 'second')
      )
  ) then
    raise exception using
      errcode = '22023',
      message = 'A runner cannot move backward.';
  end if;

  if exists (
    select 1
    from jsonb_to_recordset(p_runner_outcomes) as movement(
      player_id uuid,
      starting_base public.base_origin,
      ending_base public.base_destination
    )
    where movement.ending_base in ('first', 'second', 'third')
    group by movement.ending_base
    having count(*) > 1
  ) then
    raise exception using
      errcode = '22023',
      message = 'Two runners cannot occupy the same base.';
  end if;

  select movement.ending_base
  into batter_destination
  from jsonb_to_recordset(p_runner_outcomes) as movement(
    player_id uuid,
    starting_base public.base_origin,
    ending_base public.base_destination
  )
  where movement.starting_base = 'batter';

  if (p_result = 'double' and batter_destination = 'first')
    or (p_result = 'triple' and batter_destination not in ('third', 'home', 'out'))
    or (p_result = 'home_run' and batter_destination <> 'home')
    or (
      p_result in (
        'strikeout',
        'groundout',
        'flyout',
        'lineout',
        'popout',
        'sacrifice_fly'
      )
      and batter_destination <> 'out'
    )
  then
    raise exception using
      errcode = '22023',
      message = 'The batter destination is inconsistent with the credited result.';
  end if;

  if p_outs_recorded is null
    or p_outs_recorded < 0
    or p_outs_recorded > (3 - locked_state.outs)
    or p_outs_recorded <> out_count
  then
    raise exception using
      errcode = '22023',
      message = 'Outs recorded must match out outcomes and cannot exceed three outs.';
  end if;

  if p_rbi is null or p_rbi < 0 or p_rbi > run_count then
    raise exception using
      errcode = '22023',
      message = 'RBI must be between zero and the runs scored on the play.';
  end if;

  select coalesce(max(sequence_no), 0) + 1
  into next_sequence
  from public.plate_appearances
  where game_id = p_game_id;

  insert into public.plate_appearances (
    game_id,
    player_id,
    sequence_no,
    inning,
    outs_before,
    outs_recorded,
    result,
    rbi
  )
  values (
    p_game_id,
    current_batter_id,
    next_sequence,
    locked_state.inning,
    locked_state.outs,
    p_outs_recorded,
    p_result,
    p_rbi
  )
  returning id into created_appearance_id;

  insert into public.runner_advancements (
    plate_appearance_id,
    player_id,
    starting_base,
    ending_base
  )
  select
    created_appearance_id,
    movement.player_id,
    movement.starting_base,
    movement.ending_base
  from jsonb_to_recordset(p_runner_outcomes) as movement(
    player_id uuid,
    starting_base public.base_origin,
    ending_base public.base_destination
  );

  select movement.player_id
  into next_first_base_player_id
  from jsonb_to_recordset(p_runner_outcomes) as movement(
    player_id uuid,
    starting_base public.base_origin,
    ending_base public.base_destination
  )
  where movement.ending_base = 'first';

  select movement.player_id
  into next_second_base_player_id
  from jsonb_to_recordset(p_runner_outcomes) as movement(
    player_id uuid,
    starting_base public.base_origin,
    ending_base public.base_destination
  )
  where movement.ending_base = 'second';

  select movement.player_id
  into next_third_base_player_id
  from jsonb_to_recordset(p_runner_outcomes) as movement(
    player_id uuid,
    starting_base public.base_origin,
    ending_base public.base_destination
  )
  where movement.ending_base = 'third';

  if locked_state.outs + p_outs_recorded = 3 then
    update public.game_states
    set
      inning = locked_state.inning + 1,
      outs = 0,
      next_batter_order = resolved_next_batter_order,
      first_base_player_id = null,
      second_base_player_id = null,
      third_base_player_id = null
    where game_id = p_game_id;
  else
    update public.game_states
    set
      inning = locked_state.inning,
      outs = locked_state.outs + p_outs_recorded,
      next_batter_order = resolved_next_batter_order,
      first_base_player_id = next_first_base_player_id,
      second_base_player_id = next_second_base_player_id,
      third_base_player_id = next_third_base_player_id
    where game_id = p_game_id;
  end if;

  update public.games as game
  set team_score = (
    select count(*)::smallint
    from public.runner_advancements as advancement
    join public.plate_appearances as appearance
      on appearance.id = advancement.plate_appearance_id
    where appearance.game_id = p_game_id
      and advancement.ending_base = 'home'
  )
  where game.id = p_game_id;

  return created_appearance_id;
end;
$$;

comment on function public.record_plate_appearance(
  uuid,
  public.plate_appearance_result,
  smallint,
  smallint,
  jsonb,
  timestamptz
) is
  'Admin-only atomic offensive scoring with server-selected batter, complete movements, state locking, and stale-client protection.';

revoke all on function public.record_plate_appearance(
  uuid,
  public.plate_appearance_result,
  smallint,
  smallint,
  jsonb,
  timestamptz
) from public, anon;

grant execute on function public.record_plate_appearance(
  uuid,
  public.plate_appearance_result,
  smallint,
  smallint,
  jsonb,
  timestamptz
) to authenticated;

-- The latest movement rows contain the complete pre-play bases by starting_base, while
-- the PA itself contains inning/outs_before and its batter resolves the batting position.
create or replace function public.undo_last_plate_appearance(
  p_game_id uuid,
  p_expected_state_updated_at timestamptz
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  locked_game public.games%rowtype;
  locked_state public.game_states%rowtype;
  latest_appearance public.plate_appearances%rowtype;
  restored_batter_order smallint;
  restored_first_base_player_id uuid;
  restored_second_base_player_id uuid;
  restored_third_base_player_id uuid;
begin
  if caller_id is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication is required to undo a play.';
  end if;

  if not exists (
    select 1 from public.admin_users where user_id = caller_id
  ) then
    raise exception using
      errcode = '42501',
      message = 'Admin authorization is required to undo a play.';
  end if;

  select *
  into locked_game
  from public.games
  where id = p_game_id
  for update;

  if not found then
    raise exception using errcode = '22023', message = 'Game not found.';
  end if;

  select *
  into locked_state
  from public.game_states
  where game_id = p_game_id
  for update;

  if not found then
    raise exception using errcode = '22023', message = 'Game state not found.';
  end if;

  if locked_game.status <> 'in_progress' then
    raise exception using
      errcode = '22023',
      message = 'Only an in-progress game can be changed.';
  end if;

  if p_expected_state_updated_at is null
    or locked_state.updated_at <> p_expected_state_updated_at
  then
    raise exception using
      errcode = '40001',
      message = 'The game state changed. Refresh before undoing a play.';
  end if;

  select *
  into latest_appearance
  from public.plate_appearances
  where game_id = p_game_id
  order by sequence_no desc
  limit 1
  for update;

  if not found then
    raise exception using
      errcode = '22023',
      message = 'There is no plate appearance to undo.';
  end if;

  if not exists (
    select 1
    from public.runner_advancements
    where plate_appearance_id = latest_appearance.id
      and player_id = latest_appearance.player_id
      and starting_base = 'batter'
  ) or exists (
    select 1
    from public.runner_advancements
    where plate_appearance_id = latest_appearance.id
    group by starting_base
    having count(*) > 1
  ) then
    raise exception using
      errcode = '22023',
      message = 'The latest play does not contain complete undo data.';
  end if;

  select batting_order
  into restored_batter_order
  from public.game_lineup
  where game_id = p_game_id
    and player_id = latest_appearance.player_id;

  select player_id
  into restored_first_base_player_id
  from public.runner_advancements
  where plate_appearance_id = latest_appearance.id
    and starting_base = 'first';

  select player_id
  into restored_second_base_player_id
  from public.runner_advancements
  where plate_appearance_id = latest_appearance.id
    and starting_base = 'second';

  select player_id
  into restored_third_base_player_id
  from public.runner_advancements
  where plate_appearance_id = latest_appearance.id
    and starting_base = 'third';

  delete from public.plate_appearances
  where id = latest_appearance.id;

  update public.game_states
  set
    inning = latest_appearance.inning,
    outs = latest_appearance.outs_before,
    next_batter_order = restored_batter_order,
    first_base_player_id = restored_first_base_player_id,
    second_base_player_id = restored_second_base_player_id,
    third_base_player_id = restored_third_base_player_id
  where game_id = p_game_id;

  update public.games as game
  set team_score = (
    select count(*)::smallint
    from public.runner_advancements as advancement
    join public.plate_appearances as appearance
      on appearance.id = advancement.plate_appearance_id
    where appearance.game_id = p_game_id
      and advancement.ending_base = 'home'
  )
  where game.id = p_game_id;

  return latest_appearance.id;
end;
$$;

comment on function public.undo_last_plate_appearance(uuid, timestamptz) is
  'Admin-only atomic undo of the latest PA using its complete pre-play runner origins.';

revoke all on function public.undo_last_plate_appearance(uuid, timestamptz)
from public, anon;

grant execute on function public.undo_last_plate_appearance(uuid, timestamptz)
to authenticated;

create or replace function public.finish_game(
  p_game_id uuid,
  p_expected_state_updated_at timestamptz
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  locked_game public.games%rowtype;
  locked_state public.game_states%rowtype;
begin
  if caller_id is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication is required to finish a game.';
  end if;

  if not exists (
    select 1 from public.admin_users where user_id = caller_id
  ) then
    raise exception using
      errcode = '42501',
      message = 'Admin authorization is required to finish a game.';
  end if;

  select *
  into locked_game
  from public.games
  where id = p_game_id
  for update;

  if not found then
    raise exception using errcode = '22023', message = 'Game not found.';
  end if;

  select *
  into locked_state
  from public.game_states
  where game_id = p_game_id
  for update;

  if not found then
    raise exception using errcode = '22023', message = 'Game state not found.';
  end if;

  if locked_game.status <> 'in_progress' then
    raise exception using
      errcode = '22023',
      message = 'Only an in-progress game can be finished.';
  end if;

  if p_expected_state_updated_at is null
    or locked_state.updated_at <> p_expected_state_updated_at
  then
    raise exception using
      errcode = '40001',
      message = 'The game state changed. Refresh before finishing the game.';
  end if;

  update public.games as game
  set
    status = 'completed',
    team_score = (
      select count(*)::smallint
      from public.runner_advancements as advancement
      join public.plate_appearances as appearance
        on appearance.id = advancement.plate_appearance_id
      where appearance.game_id = p_game_id
        and advancement.ending_base = 'home'
    )
  where game.id = p_game_id;

  return p_game_id;
end;
$$;

comment on function public.finish_game(uuid, timestamptz) is
  'Admin-only atomic completion of an in-progress game with synchronized final team score.';

revoke all on function public.finish_game(uuid, timestamptz)
from public, anon;

grant execute on function public.finish_game(uuid, timestamptz)
to authenticated;
