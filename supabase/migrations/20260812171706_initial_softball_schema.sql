
-- Softball Stats initial schema
-- Public softball data is readable by everyone. Only explicitly enrolled admins can write.

create type public.game_status as enum ('draft', 'in_progress', 'completed');

create type public.plate_appearance_result as enum (
  'single',
  'double',
  'triple',
  'home_run',
  'walk',
  'hit_by_pitch',
  'strikeout',
  'groundout',
  'flyout',
  'lineout',
  'popout',
  'sacrifice_fly',
  'fielders_choice',
  'reached_on_error'
);

create type public.base_origin as enum ('batter', 'first', 'second', 'third');
create type public.base_destination as enum ('first', 'second', 'third', 'home', 'out');

create table public.players (
  id uuid primary key default gen_random_uuid(),
  first_name text not null check (btrim(first_name) <> ''),
  last_name text not null default '',
  display_name text generated always as (btrim(first_name || ' ' || last_name)) stored,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.leagues (
  id uuid primary key default gen_random_uuid(),
  name text not null check (btrim(name) <> ''),
  slug text not null unique check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.seasons (
  id uuid primary key default gen_random_uuid(),
  league_id uuid not null references public.leagues(id) on delete cascade,
  name text not null check (btrim(name) <> ''),
  start_date date,
  end_date date,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (league_id, name),
  check (end_date is null or start_date is null or end_date >= start_date)
);

create table public.season_players (
  season_id uuid not null references public.seasons(id) on delete cascade,
  player_id uuid not null references public.players(id) on delete restrict,
  created_at timestamptz not null default now(),
  primary key (season_id, player_id)
);

create table public.games (
  id uuid primary key default gen_random_uuid(),
  season_id uuid not null references public.seasons(id) on delete cascade,
  played_at timestamptz not null,
  opponent text not null check (btrim(opponent) <> ''),
  status public.game_status not null default 'draft',
  team_score smallint check (team_score >= 0),
  opponent_score smallint check (opponent_score >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, season_id)
);

create table public.game_lineup (
  game_id uuid not null,
  season_id uuid not null,
  player_id uuid not null references public.players(id) on delete restrict,
  batting_order smallint not null check (batting_order > 0),
  created_at timestamptz not null default now(),
  primary key (game_id, batting_order),
  unique (game_id, player_id),
  foreign key (game_id, season_id)
    references public.games(id, season_id) on delete cascade,
  foreign key (season_id, player_id)
    references public.season_players(season_id, player_id) on delete restrict
);

create table public.game_states (
  game_id uuid primary key references public.games(id) on delete cascade,
  inning smallint not null default 1 check (inning > 0),
  outs smallint not null default 0 check (outs between 0 and 2),
  next_batter_order smallint not null default 1 check (next_batter_order > 0),
  first_base_player_id uuid,
  second_base_player_id uuid,
  third_base_player_id uuid,
  updated_at timestamptz not null default now(),
  foreign key (game_id, first_base_player_id)
    references public.game_lineup(game_id, player_id) on delete restrict,
  foreign key (game_id, second_base_player_id)
    references public.game_lineup(game_id, player_id) on delete restrict,
  foreign key (game_id, third_base_player_id)
    references public.game_lineup(game_id, player_id) on delete restrict,
  check (
    first_base_player_id is null
    or second_base_player_id is null
    or first_base_player_id <> second_base_player_id
  ),
  check (
    first_base_player_id is null
    or third_base_player_id is null
    or first_base_player_id <> third_base_player_id
  ),
  check (
    second_base_player_id is null
    or third_base_player_id is null
    or second_base_player_id <> third_base_player_id
  )
);

create table public.plate_appearances (
  id uuid primary key default gen_random_uuid(),
  game_id uuid not null references public.games(id) on delete cascade,
  player_id uuid not null references public.players(id) on delete restrict,
  sequence_no integer not null check (sequence_no > 0),
  inning smallint not null check (inning > 0),
  outs_before smallint not null check (outs_before between 0 and 2),
  outs_recorded smallint not null default 0 check (outs_recorded between 0 and 3),
  result public.plate_appearance_result not null,
  rbi smallint not null default 0 check (rbi between 0 and 4),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (game_id, sequence_no),
  foreign key (game_id, player_id)
    references public.game_lineup(game_id, player_id) on delete restrict
);

create table public.runner_advancements (
  id uuid primary key default gen_random_uuid(),
  plate_appearance_id uuid not null references public.plate_appearances(id) on delete cascade,
  player_id uuid not null references public.players(id) on delete restrict,
  starting_base public.base_origin not null,
  ending_base public.base_destination not null,
  created_at timestamptz not null default now(),
  unique (plate_appearance_id, player_id)
);

-- Admin enrollment is deliberately separate from authentication. Creating an Auth user
-- never grants write access until the user's UUID is inserted here by a trusted operator.
create table public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create index seasons_league_id_idx on public.seasons(league_id);
create index season_players_player_id_idx on public.season_players(player_id);
create index games_season_played_at_idx on public.games(season_id, played_at desc);
create index game_lineup_player_id_idx on public.game_lineup(player_id);
create index plate_appearances_game_sequence_idx
  on public.plate_appearances(game_id, sequence_no);
create index plate_appearances_player_id_idx on public.plate_appearances(player_id);
create index runner_advancements_pa_idx on public.runner_advancements(plate_appearance_id);
create index runner_advancements_player_id_idx on public.runner_advancements(player_id);

create function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger players_set_updated_at
before update on public.players
for each row execute function public.set_updated_at();

create trigger leagues_set_updated_at
before update on public.leagues
for each row execute function public.set_updated_at();

create trigger seasons_set_updated_at
before update on public.seasons
for each row execute function public.set_updated_at();

create trigger games_set_updated_at
before update on public.games
for each row execute function public.set_updated_at();

create trigger game_states_set_updated_at
before update on public.game_states
for each row execute function public.set_updated_at();

create trigger plate_appearances_set_updated_at
before update on public.plate_appearances
for each row execute function public.set_updated_at();

-- Counts are the aggregation contract. Rate statistics are derived from counts and
-- protected against zero denominators. Future league/player/career scopes re-sum counts.
create view public.season_batting_stats
with (security_invoker = true)
as
with eligible_games as (
  select id, season_id
  from public.games
  where status <> 'draft'
),
game_counts as (
  select eg.season_id, gl.player_id, count(distinct gl.game_id)::integer as games
  from public.game_lineup gl
  join eligible_games eg on eg.id = gl.game_id
  group by eg.season_id, gl.player_id
),
pa_totals as (
  select
    eg.season_id,
    pa.player_id,
    count(*)::integer as plate_appearances,
    count(*) filter (where pa.result in (
      'single', 'double', 'triple', 'home_run', 'strikeout', 'groundout',
      'flyout', 'lineout', 'popout', 'fielders_choice', 'reached_on_error'
    ))::integer as at_bats,
    count(*) filter (where pa.result in ('single', 'double', 'triple', 'home_run'))::integer as hits,
    count(*) filter (where pa.result = 'single')::integer as singles,
    count(*) filter (where pa.result = 'double')::integer as doubles,
    count(*) filter (where pa.result = 'triple')::integer as triples,
    count(*) filter (where pa.result = 'home_run')::integer as home_runs,
    count(*) filter (where pa.result = 'walk')::integer as walks,
    count(*) filter (where pa.result = 'hit_by_pitch')::integer as hit_by_pitch,
    count(*) filter (where pa.result = 'strikeout')::integer as strikeouts,
    coalesce(sum(pa.rbi), 0)::integer as rbi,
    count(*) filter (where pa.result = 'sacrifice_fly')::integer as sacrifice_flies,
    count(*) filter (where pa.result = 'fielders_choice')::integer as fielders_choice,
    count(*) filter (where pa.result = 'reached_on_error')::integer as reached_on_error,
    coalesce(sum(case pa.result
      when 'single' then 1
      when 'double' then 2
      when 'triple' then 3
      when 'home_run' then 4
      else 0
    end), 0)::integer as total_bases
  from public.plate_appearances pa
  join eligible_games eg on eg.id = pa.game_id
  group by eg.season_id, pa.player_id
),
run_totals as (
  select eg.season_id, ra.player_id, count(*)::integer as runs
  from public.runner_advancements ra
  join public.plate_appearances pa on pa.id = ra.plate_appearance_id
  join eligible_games eg on eg.id = pa.game_id
  where ra.ending_base = 'home'
  group by eg.season_id, ra.player_id
),
stat_lines as (
  select
    sp.season_id,
    s.name as season_name,
    s.league_id,
    l.name as league_name,
    l.slug as league_slug,
    p.id as player_id,
    p.display_name as player_name,
    coalesce(gc.games, 0) as games,
    coalesce(pt.plate_appearances, 0) as plate_appearances,
    coalesce(pt.at_bats, 0) as at_bats,
    coalesce(pt.hits, 0) as hits,
    coalesce(pt.singles, 0) as singles,
    coalesce(pt.doubles, 0) as doubles,
    coalesce(pt.triples, 0) as triples,
    coalesce(pt.home_runs, 0) as home_runs,
    coalesce(pt.walks, 0) as walks,
    coalesce(pt.hit_by_pitch, 0) as hit_by_pitch,
    coalesce(pt.strikeouts, 0) as strikeouts,
    coalesce(rt.runs, 0) as runs,
    coalesce(pt.rbi, 0) as rbi,
    coalesce(pt.sacrifice_flies, 0) as sacrifice_flies,
    coalesce(pt.fielders_choice, 0) as fielders_choice,
    coalesce(pt.reached_on_error, 0) as reached_on_error,
    coalesce(pt.total_bases, 0) as total_bases
  from public.season_players sp
  join public.seasons s on s.id = sp.season_id
  join public.leagues l on l.id = s.league_id
  join public.players p on p.id = sp.player_id
  left join game_counts gc on gc.season_id = sp.season_id and gc.player_id = sp.player_id
  left join pa_totals pt on pt.season_id = sp.season_id and pt.player_id = sp.player_id
  left join run_totals rt on rt.season_id = sp.season_id and rt.player_id = sp.player_id
)
select
  stat_lines.*,
  coalesce(round(hits::numeric / nullif(at_bats, 0), 3), 0.000) as batting_average,
  coalesce(round(
    (hits + walks + hit_by_pitch)::numeric /
      nullif(at_bats + walks + hit_by_pitch + sacrifice_flies, 0),
    3
  ), 0.000) as on_base_percentage,
  coalesce(round(total_bases::numeric / nullif(at_bats, 0), 3), 0.000) as slugging_percentage,
  coalesce(round(hits::numeric / nullif(at_bats, 0), 3), 0.000)
    + coalesce(round(
      (hits + walks + hit_by_pitch)::numeric /
        nullif(at_bats + walks + hit_by_pitch + sacrifice_flies, 0),
      3
    ), 0.000)
    + coalesce(round(total_bases::numeric / nullif(at_bats, 0), 3), 0.000)
      - coalesce(round(hits::numeric / nullif(at_bats, 0), 3), 0.000) as ops
from stat_lines;

comment on view public.season_batting_stats is
  'Season batting counts and rates derived from lineups, plate appearances, and runner advancements.';

-- Enable RLS on every table exposed through the public schema.
alter table public.players enable row level security;
alter table public.leagues enable row level security;
alter table public.seasons enable row level security;
alter table public.season_players enable row level security;
alter table public.games enable row level security;
alter table public.game_lineup enable row level security;
alter table public.game_states enable row level security;
alter table public.plate_appearances enable row level security;
alter table public.runner_advancements enable row level security;
alter table public.admin_users enable row level security;

-- Public data has public SELECT and admin-only writes. The explicit grants are required
-- by newer Supabase projects and are separate from RLS policy enforcement.
revoke all on table
  public.players,
  public.leagues,
  public.seasons,
  public.season_players,
  public.games,
  public.game_lineup,
  public.game_states,
  public.plate_appearances,
  public.runner_advancements,
  public.admin_users
from anon, authenticated;

grant select on table
  public.players,
  public.leagues,
  public.seasons,
  public.season_players,
  public.games,
  public.game_lineup,
  public.game_states,
  public.plate_appearances,
  public.runner_advancements
to anon, authenticated;

grant insert, update, delete on table
  public.players,
  public.leagues,
  public.seasons,
  public.season_players,
  public.games,
  public.game_lineup,
  public.game_states,
  public.plate_appearances,
  public.runner_advancements
to authenticated;

grant select on table public.admin_users to authenticated;
grant select on table public.season_batting_stats to anon, authenticated;

create policy admin_users_read_self
on public.admin_users
for select
to authenticated
using ((select auth.uid()) = user_id);

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'players',
    'leagues',
    'seasons',
    'season_players',
    'games',
    'game_lineup',
    'game_states',
    'plate_appearances',
    'runner_advancements'
  ]
  loop
    execute format(
      'create policy public_read on public.%I for select to anon, authenticated using (true)',
      table_name
    );
    execute format(
      'create policy admin_insert on public.%I for insert to authenticated with check '
      || '(exists (select 1 from public.admin_users where user_id = (select auth.uid())))',
      table_name
    );
    execute format(
      'create policy admin_update on public.%I for update to authenticated using '
      || '(exists (select 1 from public.admin_users where user_id = (select auth.uid()))) '
      || 'with check (exists (select 1 from public.admin_users where user_id = (select auth.uid())))',
      table_name
    );
    execute format(
      'create policy admin_delete on public.%I for delete to authenticated using '
      || '(exists (select 1 from public.admin_users where user_id = (select auth.uid())))',
      table_name
    );
  end loop;
end;
$$;
