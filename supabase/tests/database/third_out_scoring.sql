-- Regression fixtures use an enrolled admin and isolated data; all writes roll back.
begin;
select set_config('test.softball_admin_id',
  (select user_id::text from public.admin_users order by created_at limit 1), true);
set local role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.softball_admin_id'), true);
do $$
<<test>>
declare
  game_id uuid;
  league_id uuid := gen_random_uuid();
  season_id uuid := gen_random_uuid();
  snapshot_at timestamptz;
  play_id uuid;
  first_runner uuid := gen_random_uuid();
  third_runner uuid := gen_random_uuid();
  batter uuid := gen_random_uuid();
  movements jsonb;
begin
  insert into public.leagues(id, name, slug)
  values (league_id, 'Third-out fixture', 'third-out-fixture-' || league_id::text);
  insert into public.seasons(id, league_id, name)
  values (season_id, league_id, 'Third-out fixture');
  insert into public.players(id, first_name, last_name) values
    (first_runner, 'First', 'Fixture'), (third_runner, 'Third', 'Fixture'),
    (batter, 'Batter', 'Fixture');
  insert into public.season_players(season_id, player_id) values
    (season_id, first_runner), (season_id, third_runner), (season_id, batter);
  game_id := public.create_game_with_lineup(
    league_id, season_id,
    'Third-out regression fixture', '2026-09-09 16:00:00+00',
    array[first_runner, third_runner, batter]);
  update public.game_states set outs = 2, next_batter_order = 3,
    first_base_player_id = first_runner, third_base_player_id = third_runner
  where public.game_states.game_id = test.game_id;
  select updated_at into snapshot_at from public.game_states
  where public.game_states.game_id = test.game_id;

  -- Retired result must fail atomically, including for an older client.
  begin
    perform public.record_plate_appearance(game_id, 'hit_by_pitch', 0::smallint, 0::smallint,
      '[]'::jsonb, snapshot_at);
    raise exception 'Retired result unexpectedly accepted';
  exception when invalid_parameter_value then
    if sqlerrm not like 'This scoring result is no longer supported.%' then raise; end if;
  end;

  -- Holding a runner from first is allowed when a single ends with an out elsewhere.
  movements := jsonb_build_array(
    jsonb_build_object('player_id',first_runner,'starting_base','first','ending_base','first'),
    jsonb_build_object('player_id',third_runner,'starting_base','third','ending_base','out'),
    jsonb_build_object('player_id',batter,'starting_base','batter','ending_base','first'));
  play_id := public.record_plate_appearance(game_id, 'single', 1::smallint, 0::smallint,
    movements, snapshot_at);
  if not exists (select 1 from public.game_states s where s.game_id = test.game_id
    and inning = 2 and outs = 0 and first_base_player_id is null
    and second_base_player_id is null and third_base_player_id is null)
    or (select team_score from public.games where id = game_id) <> 0 then
    raise exception 'Held runner must not score and bases must clear';
  end if;
  select updated_at into snapshot_at from public.game_states s where s.game_id = test.game_id;
  perform public.undo_last_plate_appearance(game_id, snapshot_at);

  -- A routine third-out groundout also holds runners, with zero runs and RBI.
  select updated_at into snapshot_at from public.game_states s where s.game_id = test.game_id;
  movements := jsonb_build_array(
    jsonb_build_object('player_id',first_runner,'starting_base','first','ending_base','first'),
    jsonb_build_object('player_id',third_runner,'starting_base','third','ending_base','third'),
    jsonb_build_object('player_id',batter,'starting_base','batter','ending_base','out'));
  play_id := public.record_plate_appearance(game_id, 'groundout', 1::smallint, 0::smallint,
    movements, snapshot_at);
  if (select team_score from public.games where id = game_id) <> 0
    or (select rbi from public.plate_appearances where id = play_id) <> 0 then
    raise exception 'Third-out groundout must not automatically score';
  end if;
  select updated_at into snapshot_at from public.game_states s where s.game_id = test.game_id;
  perform public.undo_last_plate_appearance(game_id, snapshot_at);

  -- Explicit run before a tag third out remains supported and updates runs/RBI.
  select updated_at into snapshot_at from public.game_states s where s.game_id = test.game_id;
  movements := jsonb_build_array(
    jsonb_build_object('player_id',first_runner,'starting_base','first','ending_base','out'),
    jsonb_build_object('player_id',third_runner,'starting_base','third','ending_base','home'),
    jsonb_build_object('player_id',batter,'starting_base','batter','ending_base','first'));
  play_id := public.record_plate_appearance(game_id, 'single', 1::smallint, 1::smallint,
    movements, snapshot_at);
  if (select team_score from public.games where id = game_id) <> 1
    or (select rbi from public.plate_appearances where id = play_id) <> 1 then
    raise exception 'Explicit run and RBI were not saved';
  end if;
  select updated_at into snapshot_at from public.game_states s where s.game_id = test.game_id;
  perform public.undo_last_plate_appearance(game_id, snapshot_at);
  if (select team_score from public.games where id = game_id) <> 0 then
    raise exception 'Undo did not remove the explicit run';
  end if;
end;
$$;
rollback;
