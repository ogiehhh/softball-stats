-- Retire the scoring option while retaining historical events and rate calculations.
-- Preserve the admin allowlist, invoker security, stale-state checks and atomic scoring.
CREATE OR REPLACE FUNCTION public.record_plate_appearance(p_game_id uuid, p_result public.plate_appearance_result, p_outs_recorded smallint, p_rbi smallint, p_runner_outcomes jsonb, p_expected_state_updated_at timestamp with time zone)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY INVOKER
 SET search_path TO ''
AS $function$
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

  if p_result = 'hit_by_pitch' then
    raise exception using
      errcode = '22023',
      message = 'This scoring result is no longer supported. Refresh and choose another result.';
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

  -- After the third out, held runners are left on base and all bases are cleared.
  if locked_state.outs + out_count < 3 and exists (
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
$function$
;
