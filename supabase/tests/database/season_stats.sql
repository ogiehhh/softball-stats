-- Run with psql after migrations. The fixture is isolated and always rolls back.
begin;

insert into public.leagues (id, name, slug)
values ('10000000-0000-4000-8000-000000000001', 'Stats Test League', 'stats-test-league');

insert into public.seasons (id, league_id, name, start_date, end_date)
values (
  '10000000-0000-4000-8000-000000000101',
  '10000000-0000-4000-8000-000000000001',
  'Stats Test Season',
  '2026-01-01',
  '2026-02-01'
);

insert into public.players (id, first_name, last_name)
values
  ('10000000-0000-4000-8000-000000001001', 'Test', 'Ada'),
  ('10000000-0000-4000-8000-000000001002', 'Test', 'Betty');

insert into public.season_players (season_id, player_id)
values
  ('10000000-0000-4000-8000-000000000101', '10000000-0000-4000-8000-000000001001'),
  ('10000000-0000-4000-8000-000000000101', '10000000-0000-4000-8000-000000001002');

insert into public.games (id, season_id, played_at, opponent, status, team_score)
values
  (
    '10000000-0000-4000-8000-000000002001',
    '10000000-0000-4000-8000-000000000101',
    '2026-01-10 12:00:00+00',
    'Stats Fixture A',
    'completed',
    4
  ),
  (
    '10000000-0000-4000-8000-000000002002',
    '10000000-0000-4000-8000-000000000101',
    '2026-01-17 12:00:00+00',
    'Stats Fixture B',
    'completed',
    5
  );

insert into public.game_lineup (game_id, season_id, player_id, batting_order)
values
  ('10000000-0000-4000-8000-000000002001', '10000000-0000-4000-8000-000000000101', '10000000-0000-4000-8000-000000001001', 1),
  ('10000000-0000-4000-8000-000000002001', '10000000-0000-4000-8000-000000000101', '10000000-0000-4000-8000-000000001002', 2),
  ('10000000-0000-4000-8000-000000002002', '10000000-0000-4000-8000-000000000101', '10000000-0000-4000-8000-000000001001', 1),
  ('10000000-0000-4000-8000-000000002002', '10000000-0000-4000-8000-000000000101', '10000000-0000-4000-8000-000000001002', 2);

insert into public.plate_appearances (
  id, game_id, player_id, sequence_no, inning, outs_before, outs_recorded, result, rbi
)
values
  ('10000000-0000-4000-8000-000000003001', '10000000-0000-4000-8000-000000002001', '10000000-0000-4000-8000-000000001001', 1, 1, 0, 0, 'single', 0),
  ('10000000-0000-4000-8000-000000003002', '10000000-0000-4000-8000-000000002001', '10000000-0000-4000-8000-000000001002', 2, 1, 0, 0, 'single', 2),
  ('10000000-0000-4000-8000-000000003003', '10000000-0000-4000-8000-000000002001', '10000000-0000-4000-8000-000000001001', 3, 1, 0, 0, 'walk', 0),
  ('10000000-0000-4000-8000-000000003004', '10000000-0000-4000-8000-000000002001', '10000000-0000-4000-8000-000000001002', 4, 1, 0, 0, 'walk', 0),
  ('10000000-0000-4000-8000-000000003005', '10000000-0000-4000-8000-000000002001', '10000000-0000-4000-8000-000000001002', 5, 1, 0, 1, 'sacrifice_fly', 1),
  ('10000000-0000-4000-8000-000000003006', '10000000-0000-4000-8000-000000002002', '10000000-0000-4000-8000-000000001001', 1, 1, 0, 0, 'double', 0),
  ('10000000-0000-4000-8000-000000003007', '10000000-0000-4000-8000-000000002002', '10000000-0000-4000-8000-000000001002', 2, 1, 0, 0, 'home_run', 2),
  ('10000000-0000-4000-8000-000000003008', '10000000-0000-4000-8000-000000002002', '10000000-0000-4000-8000-000000001001', 3, 1, 0, 0, 'reached_on_error', 0),
  ('10000000-0000-4000-8000-000000003009', '10000000-0000-4000-8000-000000002002', '10000000-0000-4000-8000-000000001002', 4, 1, 0, 1, 'strikeout', 0),
  ('10000000-0000-4000-8000-000000003010', '10000000-0000-4000-8000-000000002002', '10000000-0000-4000-8000-000000001001', 5, 1, 1, 0, 'triple', 0);

insert into public.runner_advancements (
  id, plate_appearance_id, player_id, starting_base, ending_base
)
values
  ('10000000-0000-4000-8000-000000004001', '10000000-0000-4000-8000-000000003001', '10000000-0000-4000-8000-000000001001', 'batter', 'home'),
  ('10000000-0000-4000-8000-000000004002', '10000000-0000-4000-8000-000000003003', '10000000-0000-4000-8000-000000001001', 'batter', 'home'),
  ('10000000-0000-4000-8000-000000004003', '10000000-0000-4000-8000-000000003006', '10000000-0000-4000-8000-000000001001', 'batter', 'home'),
  ('10000000-0000-4000-8000-000000004004', '10000000-0000-4000-8000-000000003008', '10000000-0000-4000-8000-000000001001', 'batter', 'home');

do $$
declare
  ada public.season_batting_stats%rowtype;
  betty public.season_batting_stats%rowtype;
begin
  select * into strict ada
  from public.season_batting_stats
  where season_id = '10000000-0000-4000-8000-000000000101'
    and player_id = '10000000-0000-4000-8000-000000001001';

  if ada.games <> 2
    or ada.plate_appearances <> 5
    or ada.at_bats <> 4
    or ada.hits <> 3
    or ada.walks <> 1
    or ada.reached_on_error <> 1
    or ada.runs <> 4
    or ada.batting_average <> 0.750
    or ada.on_base_percentage <> 0.800
    or ada.slugging_percentage <> 1.500
    or ada.ops <> 2.300
  then
    raise exception 'Isolated Ada statistics do not match the scoring rules: %', row_to_json(ada);
  end if;

  select * into strict betty
  from public.season_batting_stats
  where season_id = '10000000-0000-4000-8000-000000000101'
    and player_id = '10000000-0000-4000-8000-000000001002';

  if betty.games <> 2
    or betty.plate_appearances <> 5
    or betty.at_bats <> 3
    or betty.hits <> 2
    or betty.walks <> 1
    or betty.sacrifice_flies <> 1
    or betty.rbi <> 5
    or betty.on_base_percentage <> 0.600
  then
    raise exception 'Isolated Betty statistics do not match the scoring rules: %', row_to_json(betty);
  end if;
end;
$$;

rollback;
