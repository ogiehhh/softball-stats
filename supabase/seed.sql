-- Deterministic development roster. Safe to rerun.
-- Games are intentionally excluded so reset data cannot appear as real results.

insert into public.leagues (id, name, slug, active)
values ('00000000-0000-4000-8000-000000000001', 'Demo League', 'demo-league', true)
on conflict (id) do update set name = excluded.name, slug = excluded.slug, active = excluded.active;

insert into public.seasons (id, league_id, name, start_date, end_date, active)
values (
  '00000000-0000-4000-8000-000000000101',
  '00000000-0000-4000-8000-000000000001',
  'Fall 2026',
  '2026-09-01',
  '2026-11-15',
  true
)
on conflict (id) do update set
  league_id = excluded.league_id,
  name = excluded.name,
  start_date = excluded.start_date,
  end_date = excluded.end_date,
  active = excluded.active;

insert into public.players (id, first_name, last_name, active)
values
  ('00000000-0000-4000-8000-000000001001', 'Ada', 'Ace', true),
  ('00000000-0000-4000-8000-000000001002', 'Betty', 'Base', true),
  ('00000000-0000-4000-8000-000000001003', 'Carla', 'Curve', true),
  ('00000000-0000-4000-8000-000000001004', 'Dani', 'Diamond', true)
on conflict (id) do update set
  first_name = excluded.first_name,
  last_name = excluded.last_name,
  active = excluded.active;

insert into public.season_players (season_id, player_id)
select '00000000-0000-4000-8000-000000000101', id
from public.players
where id in (
  '00000000-0000-4000-8000-000000001001',
  '00000000-0000-4000-8000-000000001002',
  '00000000-0000-4000-8000-000000001003',
  '00000000-0000-4000-8000-000000001004'
)
on conflict (season_id, player_id) do nothing;
