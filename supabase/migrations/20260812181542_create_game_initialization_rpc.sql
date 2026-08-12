-- Atomically starts a game, fixes its lineup, and creates the persisted resume state.
-- SECURITY INVOKER deliberately keeps all writes behind the existing table RLS policies.
create function public.create_game_with_lineup(
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
    from public.seasons s
    join public.leagues l on l.id = s.league_id
    where s.id = p_season_id
      and s.league_id = p_league_id
      and s.active
      and l.active
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
  join public.season_players sp
    on sp.season_id = p_season_id
    and sp.player_id = lineup.player_id;

  if rostered_count <> lineup_count then
    raise exception using
      errcode = '22023',
      message = 'Every lineup player must belong to the selected season roster.';
  end if;

  insert into public.games (
    season_id,
    played_at,
    opponent,
    status
  )
  values (
    p_season_id,
    p_played_at,
    btrim(p_opponent),
    'in_progress'
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

comment on function public.create_game_with_lineup(uuid, uuid, text, timestamptz, uuid[]) is
  'Admin-only atomic game initialization: game, ordered roster-valid lineup, and empty inning-one state.';

revoke all on function public.create_game_with_lineup(uuid, uuid, text, timestamptz, uuid[])
from public, anon;

grant execute on function public.create_game_with_lineup(uuid, uuid, text, timestamptz, uuid[])
to authenticated;
