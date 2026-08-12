-- Recoverable archive support for leagues and games.
-- Archive metadata is stored only on the directly archived row. A league archive
-- suppresses its descendants without rewriting them, so restore preserves any
-- independently archived child games.

alter table public.leagues
  add column archived_at timestamptz,
  add column archived_by uuid references auth.users(id) on delete set null,
  add constraint leagues_archive_metadata_check
    check (archived_at is not null or archived_by is null);

alter table public.games
  add column archived_at timestamptz,
  add column archived_by uuid references auth.users(id) on delete set null,
  add constraint games_archive_metadata_check
    check (archived_at is not null or archived_by is null);

create index leagues_archived_at_idx
  on public.leagues(archived_at)
  where archived_at is not null;

create index games_archived_at_idx
  on public.games(archived_at)
  where archived_at is not null;

create index games_season_visible_played_at_idx
  on public.games(season_id, played_at desc)
  where archived_at is null;

-- Public reads exclude archived branches at the policy boundary. Enrolled admins
-- retain read access so the recovery UI can identify and restore archived records.
drop policy public_read on public.leagues;
create policy visible_read
on public.leagues
for select
to anon, authenticated
using (archived_at is null);

create policy admin_read_archived
on public.leagues
for select
to authenticated
using (exists (
  select 1 from public.admin_users
  where user_id = (select auth.uid())
));

drop policy public_read on public.seasons;
create policy visible_read
on public.seasons
for select
to anon, authenticated
using (exists (
  select 1
  from public.leagues as league
  where league.id = league_id
    and league.archived_at is null
));

create policy admin_read_archived
on public.seasons
for select
to authenticated
using (exists (
  select 1 from public.admin_users
  where user_id = (select auth.uid())
));

drop policy public_read on public.season_players;
create policy visible_read
on public.season_players
for select
to anon, authenticated
using (exists (
  select 1
  from public.seasons as season
  join public.leagues as league on league.id = season.league_id
  where season.id = season_id
    and league.archived_at is null
));

create policy admin_read_archived
on public.season_players
for select
to authenticated
using (exists (
  select 1 from public.admin_users
  where user_id = (select auth.uid())
));

drop policy public_read on public.games;
create policy visible_read
on public.games
for select
to anon, authenticated
using (
  archived_at is null
  and exists (
    select 1
    from public.seasons as season
    join public.leagues as league on league.id = season.league_id
    where season.id = season_id
      and league.archived_at is null
  )
);

create policy admin_read_archived
on public.games
for select
to authenticated
using (exists (
  select 1 from public.admin_users
  where user_id = (select auth.uid())
));

drop policy public_read on public.game_lineup;
create policy visible_read
on public.game_lineup
for select
to anon, authenticated
using (exists (
  select 1
  from public.games as game
  join public.seasons as season on season.id = game.season_id
  join public.leagues as league on league.id = season.league_id
  where game.id = game_id
    and game.archived_at is null
    and league.archived_at is null
));

create policy admin_read_archived
on public.game_lineup
for select
to authenticated
using (exists (
  select 1 from public.admin_users
  where user_id = (select auth.uid())
));

drop policy public_read on public.game_states;
create policy visible_read
on public.game_states
for select
to anon, authenticated
using (exists (
  select 1
  from public.games as game
  join public.seasons as season on season.id = game.season_id
  join public.leagues as league on league.id = season.league_id
  where game.id = game_id
    and game.archived_at is null
    and league.archived_at is null
));

create policy admin_read_archived
on public.game_states
for select
to authenticated
using (exists (
  select 1 from public.admin_users
  where user_id = (select auth.uid())
));

drop policy public_read on public.plate_appearances;
create policy visible_read
on public.plate_appearances
for select
to anon, authenticated
using (exists (
  select 1
  from public.games as game
  join public.seasons as season on season.id = game.season_id
  join public.leagues as league on league.id = season.league_id
  where game.id = game_id
    and game.archived_at is null
    and league.archived_at is null
));

create policy admin_read_archived
on public.plate_appearances
for select
to authenticated
using (exists (
  select 1 from public.admin_users
  where user_id = (select auth.uid())
));

drop policy public_read on public.runner_advancements;
create policy visible_read
on public.runner_advancements
for select
to anon, authenticated
using (exists (
  select 1
  from public.plate_appearances as appearance
  join public.games as game on game.id = appearance.game_id
  join public.seasons as season on season.id = game.season_id
  join public.leagues as league on league.id = season.league_id
  where appearance.id = plate_appearance_id
    and game.archived_at is null
    and league.archived_at is null
));

create policy admin_read_archived
on public.runner_advancements
for select
to authenticated
using (exists (
  select 1 from public.admin_users
  where user_id = (select auth.uid())
));

-- Normal authenticated API clients cannot physically delete leagues or games.
drop policy admin_delete on public.leagues;
drop policy admin_delete on public.games;
revoke delete on table public.leagues, public.games from authenticated;

-- Statistics exclude both independently archived games and every game beneath an
-- archived league. Restoring only changes visibility; event history is untouched.
create or replace view public.season_batting_stats
with (security_invoker = true)
as
with eligible_games as (
  select game.id, game.season_id
  from public.games as game
  join public.seasons as season on season.id = game.season_id
  join public.leagues as league on league.id = season.league_id
  where game.status <> 'draft'
    and game.archived_at is null
    and league.archived_at is null
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
  where l.archived_at is null
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
  'Visible season batting counts and rates; archived games and archived league branches are excluded.';

create function public.archive_game(p_game_id uuid)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  caller_id uuid := auth.uid();
  target public.games%rowtype;
begin
  if caller_id is null or not exists (
    select 1 from public.admin_users where user_id = caller_id
  ) then
    raise insufficient_privilege using message = 'Admin authorization is required.';
  end if;

  select * into target
  from public.games
  where id = p_game_id
  for update;

  if not found then
    raise invalid_parameter_value using message = 'Game not found.';
  end if;

  if target.archived_at is not null then
    raise invalid_parameter_value using message = 'Game is already archived.';
  end if;

  update public.games
  set archived_at = clock_timestamp(), archived_by = caller_id
  where id = p_game_id;

  return p_game_id;
end;
$$;

create function public.restore_game(p_game_id uuid)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  caller_id uuid := auth.uid();
  target public.games%rowtype;
begin
  if caller_id is null or not exists (
    select 1 from public.admin_users where user_id = caller_id
  ) then
    raise insufficient_privilege using message = 'Admin authorization is required.';
  end if;

  select * into target
  from public.games
  where id = p_game_id
  for update;

  if not found then
    raise invalid_parameter_value using message = 'Game not found.';
  end if;

  if target.archived_at is null then
    raise invalid_parameter_value using message = 'Game is not archived.';
  end if;

  update public.games
  set archived_at = null, archived_by = null
  where id = p_game_id;

  return p_game_id;
end;
$$;

create function public.archive_league(p_league_id uuid)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  caller_id uuid := auth.uid();
  target public.leagues%rowtype;
begin
  if caller_id is null or not exists (
    select 1 from public.admin_users where user_id = caller_id
  ) then
    raise insufficient_privilege using message = 'Admin authorization is required.';
  end if;

  select * into target
  from public.leagues
  where id = p_league_id
  for update;

  if not found then
    raise invalid_parameter_value using message = 'League not found.';
  end if;

  if target.archived_at is not null then
    raise invalid_parameter_value using message = 'League is already archived.';
  end if;

  update public.leagues
  set archived_at = clock_timestamp(), archived_by = caller_id
  where id = p_league_id;

  return p_league_id;
end;
$$;

create function public.restore_league(p_league_id uuid)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  caller_id uuid := auth.uid();
  target public.leagues%rowtype;
begin
  if caller_id is null or not exists (
    select 1 from public.admin_users where user_id = caller_id
  ) then
    raise insufficient_privilege using message = 'Admin authorization is required.';
  end if;

  select * into target
  from public.leagues
  where id = p_league_id
  for update;

  if not found then
    raise invalid_parameter_value using message = 'League not found.';
  end if;

  if target.archived_at is null then
    raise invalid_parameter_value using message = 'League is not archived.';
  end if;

  update public.leagues
  set archived_at = null, archived_by = null
  where id = p_league_id;

  return p_league_id;
end;
$$;

revoke execute on function public.archive_game(uuid) from public, anon;
revoke execute on function public.restore_game(uuid) from public, anon;
revoke execute on function public.archive_league(uuid) from public, anon;
revoke execute on function public.restore_league(uuid) from public, anon;
grant execute on function public.archive_game(uuid) to authenticated;
grant execute on function public.restore_game(uuid) to authenticated;
grant execute on function public.archive_league(uuid) to authenticated;
grant execute on function public.restore_league(uuid) to authenticated;

-- Inserts and scoring mutations are rejected when either the game or its parent
-- league is archived. Archive/restore metadata updates themselves remain allowed.
create function public.reject_archived_game_write()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if exists (
    select 1
    from public.seasons as season
    join public.leagues as league on league.id = season.league_id
    where season.id = new.season_id
      and league.archived_at is not null
  ) then
    raise invalid_parameter_value using message = 'Archived leagues cannot accept game changes.';
  end if;

  if tg_op = 'UPDATE' and old.archived_at is not null then
    raise invalid_parameter_value using message = 'Archived games cannot be changed.';
  end if;

  return new;
end;
$$;

create trigger games_reject_archived_business_write
before insert or update of season_id, played_at, opponent, status, team_score, opponent_score
on public.games
for each row execute function public.reject_archived_game_write();

create function public.reject_archived_plate_appearance_write()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  target_game_id uuid;
begin
  if tg_op = 'DELETE' then
    target_game_id := old.game_id;
  else
    target_game_id := new.game_id;
  end if;

  if exists (
    select 1
    from public.games as game
    join public.seasons as season on season.id = game.season_id
    join public.leagues as league on league.id = season.league_id
    where game.id = target_game_id
      and (game.archived_at is not null or league.archived_at is not null)
  ) then
    raise invalid_parameter_value using message = 'Archived games cannot be scored.';
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

create trigger plate_appearances_reject_archived_write
before insert or update or delete
on public.plate_appearances
for each row execute function public.reject_archived_plate_appearance_write();

comment on column public.leagues.archived_at is
  'When set, the league and all descendants are hidden from normal reads and statistics.';
comment on column public.leagues.archived_by is
  'Admin user who archived the league; retained as null if that Auth user is later removed.';
comment on column public.games.archived_at is
  'When set, this game is hidden and excluded from statistics without deleting its event history.';
comment on column public.games.archived_by is
  'Admin user who archived the game; retained as null if that Auth user is later removed.';
