-- Admin-managed season lifecycle. Completed seasons remain visible and keep
-- contributing to historical, league, and career statistics. Archived seasons
-- are recoverably hidden with their entire branch of game data.

alter table public.seasons
  add column completed_at timestamptz,
  add column completed_by uuid references auth.users(id) on delete set null,
  add column archived_at timestamptz,
  add column archived_by uuid references auth.users(id) on delete set null;

-- Preserve any pre-existing inactive seasons as completed historical records.
update public.seasons
set completed_at = coalesce(updated_at, created_at, clock_timestamp())
where not active and completed_at is null;

alter table public.seasons
  add constraint seasons_completion_state_check check (
    (active and completed_at is null and completed_by is null)
    or (not active and completed_at is not null)
  ),
  add constraint seasons_archive_metadata_check
    check (archived_at is not null or archived_by is null);

create unique index seasons_league_name_ci_idx
  on public.seasons(league_id, lower(name));
create index seasons_visible_league_start_idx
  on public.seasons(league_id, start_date desc)
  where archived_at is null;
create index seasons_archived_at_idx
  on public.seasons(archived_at)
  where archived_at is not null;
create index seasons_completed_by_idx on public.seasons(completed_by);
create index seasons_archived_by_idx on public.seasons(archived_by);

-- Deletion from a browser client is never permanent.
drop policy admin_delete on public.seasons;
revoke delete on table public.seasons from authenticated;

-- Archived seasons and all of their descendants are hidden from normal reads.
alter policy visible_read on public.seasons
to anon
using (
  archived_at is null
  and exists (
    select 1 from public.leagues as league
    where league.id = league_id
      and league.archived_at is null
  )
);

alter policy authenticated_read on public.seasons
to authenticated
using (
  (
    archived_at is null
    and exists (
      select 1 from public.leagues as league
      where league.id = league_id
        and league.archived_at is null
    )
  )
  or exists (
    select 1 from public.admin_users
    where user_id = (select auth.uid())
  )
);

alter policy visible_read on public.season_players
to anon
using (exists (
  select 1
  from public.seasons as season
  join public.leagues as league on league.id = season.league_id
  where season.id = season_id
    and season.archived_at is null
    and league.archived_at is null
));

alter policy authenticated_read on public.season_players
to authenticated
using (
  exists (
    select 1
    from public.seasons as season
    join public.leagues as league on league.id = season.league_id
    where season.id = season_id
      and season.archived_at is null
      and league.archived_at is null
  )
  or exists (
    select 1 from public.admin_users
    where user_id = (select auth.uid())
  )
);

alter policy visible_read on public.games
to anon
using (
  archived_at is null
  and exists (
    select 1
    from public.seasons as season
    join public.leagues as league on league.id = season.league_id
    where season.id = season_id
      and season.archived_at is null
      and league.archived_at is null
  )
);

alter policy authenticated_read on public.games
to authenticated
using (
  (
    archived_at is null
    and exists (
      select 1
      from public.seasons as season
      join public.leagues as league on league.id = season.league_id
      where season.id = season_id
        and season.archived_at is null
        and league.archived_at is null
    )
  )
  or exists (
    select 1 from public.admin_users
    where user_id = (select auth.uid())
  )
);

alter policy visible_read on public.game_lineup
to anon
using (exists (
  select 1
  from public.games as game
  join public.seasons as season on season.id = game.season_id
  join public.leagues as league on league.id = season.league_id
  where game.id = game_id
    and game.archived_at is null
    and season.archived_at is null
    and league.archived_at is null
));

alter policy authenticated_read on public.game_lineup
to authenticated
using (
  exists (
    select 1
    from public.games as game
    join public.seasons as season on season.id = game.season_id
    join public.leagues as league on league.id = season.league_id
    where game.id = game_id
      and game.archived_at is null
      and season.archived_at is null
      and league.archived_at is null
  )
  or exists (
    select 1 from public.admin_users
    where user_id = (select auth.uid())
  )
);

alter policy visible_read on public.game_states
to anon
using (exists (
  select 1
  from public.games as game
  join public.seasons as season on season.id = game.season_id
  join public.leagues as league on league.id = season.league_id
  where game.id = game_id
    and game.archived_at is null
    and season.archived_at is null
    and league.archived_at is null
));

alter policy authenticated_read on public.game_states
to authenticated
using (
  exists (
    select 1
    from public.games as game
    join public.seasons as season on season.id = game.season_id
    join public.leagues as league on league.id = season.league_id
    where game.id = game_id
      and game.archived_at is null
      and season.archived_at is null
      and league.archived_at is null
  )
  or exists (
    select 1 from public.admin_users
    where user_id = (select auth.uid())
  )
);

alter policy visible_read on public.plate_appearances
to anon
using (exists (
  select 1
  from public.games as game
  join public.seasons as season on season.id = game.season_id
  join public.leagues as league on league.id = season.league_id
  where game.id = game_id
    and game.archived_at is null
    and season.archived_at is null
    and league.archived_at is null
));

alter policy authenticated_read on public.plate_appearances
to authenticated
using (
  exists (
    select 1
    from public.games as game
    join public.seasons as season on season.id = game.season_id
    join public.leagues as league on league.id = season.league_id
    where game.id = game_id
      and game.archived_at is null
      and season.archived_at is null
      and league.archived_at is null
  )
  or exists (
    select 1 from public.admin_users
    where user_id = (select auth.uid())
  )
);

alter policy visible_read on public.runner_advancements
to anon
using (exists (
  select 1
  from public.plate_appearances as appearance
  join public.games as game on game.id = appearance.game_id
  join public.seasons as season on season.id = game.season_id
  join public.leagues as league on league.id = season.league_id
  where appearance.id = plate_appearance_id
    and game.archived_at is null
    and season.archived_at is null
    and league.archived_at is null
));

alter policy authenticated_read on public.runner_advancements
to authenticated
using (
  exists (
    select 1
    from public.plate_appearances as appearance
    join public.games as game on game.id = appearance.game_id
    join public.seasons as season on season.id = game.season_id
    join public.leagues as league on league.id = season.league_id
    where appearance.id = plate_appearance_id
      and game.archived_at is null
      and season.archived_at is null
      and league.archived_at is null
  )
  or exists (
    select 1 from public.admin_users
    where user_id = (select auth.uid())
  )
);

-- Keep completed seasons in the aggregate contract; only archived branches are
-- excluded, even when the caller is an admin who can otherwise read archives.
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
    and season.archived_at is null
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
  where s.archived_at is null
    and l.archived_at is null
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
  'Visible season batting counts and rates; completed seasons remain historical while archived season, game, and league branches are excluded.';

create function public.create_season(
  p_league_id uuid,
  p_name text,
  p_start_date date default null,
  p_end_date date default null
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  normalized_name text := regexp_replace(btrim(coalesce(p_name, '')), '\s+', ' ', 'g');
  created_season_id uuid;
  source_season_id uuid;
begin
  if caller_id is null or not exists (
    select 1 from public.admin_users where user_id = caller_id
  ) then
    raise insufficient_privilege using message = 'Admin authorization is required.';
  end if;

  if p_league_id is null or not exists (
    select 1 from public.leagues
    where id = p_league_id and active and archived_at is null
  ) then
    raise invalid_parameter_value using message = 'Choose an active league.';
  end if;

  if normalized_name = '' or char_length(normalized_name) > 100 then
    raise invalid_parameter_value using message = 'Enter a season name of 100 characters or fewer.';
  end if;

  if p_start_date is not null and p_end_date is not null and p_end_date < p_start_date then
    raise invalid_parameter_value using message = 'The season end date cannot be before its start date.';
  end if;

  if exists (
    select 1 from public.seasons
    where league_id = p_league_id and lower(name) = lower(normalized_name)
  ) then
    raise unique_violation using message = 'A season with this name already exists in this league.';
  end if;

  select id into source_season_id
  from public.seasons
  where league_id = p_league_id and archived_at is null
  order by active desc, start_date desc nulls last, created_at desc
  limit 1;

  insert into public.seasons (league_id, name, start_date, end_date, active)
  values (p_league_id, normalized_name, p_start_date, p_end_date, true)
  returning id into created_season_id;

  if source_season_id is not null then
    insert into public.season_players (season_id, player_id)
    select created_season_id, player_id
    from public.season_players
    where season_id = source_season_id;
  end if;

  return created_season_id;
exception
  when unique_violation then
    raise unique_violation using message = 'A season with this name already exists in this league.';
end;
$$;

create function public.complete_season(p_season_id uuid)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  target public.seasons%rowtype;
begin
  if caller_id is null or not exists (
    select 1 from public.admin_users where user_id = caller_id
  ) then
    raise insufficient_privilege using message = 'Admin authorization is required.';
  end if;

  select * into target from public.seasons where id = p_season_id for update;
  if not found then raise invalid_parameter_value using message = 'Season not found.'; end if;
  if target.archived_at is not null then
    raise invalid_parameter_value using message = 'Archived seasons cannot be completed.';
  end if;
  if not exists (
    select 1 from public.leagues
    where id = target.league_id and archived_at is null
  ) then
    raise invalid_parameter_value using message = 'Restore the league before completing this season.';
  end if;
  if not target.active then
    raise invalid_parameter_value using message = 'Season is already completed.';
  end if;
  if exists (
    select 1 from public.games
    where season_id = p_season_id
      and archived_at is null
      and status <> 'completed'
  ) then
    raise invalid_parameter_value using message = 'Finish or delete every unfinished game before completing this season.';
  end if;

  update public.seasons
  set active = false, completed_at = clock_timestamp(), completed_by = caller_id
  where id = p_season_id;
  return p_season_id;
end;
$$;

create function public.reopen_season(p_season_id uuid)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  target public.seasons%rowtype;
begin
  if caller_id is null or not exists (
    select 1 from public.admin_users where user_id = caller_id
  ) then
    raise insufficient_privilege using message = 'Admin authorization is required.';
  end if;

  select * into target from public.seasons where id = p_season_id for update;
  if not found then raise invalid_parameter_value using message = 'Season not found.'; end if;
  if target.archived_at is not null then
    raise invalid_parameter_value using message = 'Restore the season before reopening it.';
  end if;
  if not exists (
    select 1 from public.leagues
    where id = target.league_id and active and archived_at is null
  ) then
    raise invalid_parameter_value using message = 'Restore or reactivate the league before reopening this season.';
  end if;
  if target.active then
    raise invalid_parameter_value using message = 'Season is already active.';
  end if;

  update public.seasons
  set active = true, completed_at = null, completed_by = null
  where id = p_season_id;
  return p_season_id;
end;
$$;

create function public.archive_season(p_season_id uuid)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  target public.seasons%rowtype;
begin
  if caller_id is null or not exists (
    select 1 from public.admin_users where user_id = caller_id
  ) then
    raise insufficient_privilege using message = 'Admin authorization is required.';
  end if;
  select * into target from public.seasons where id = p_season_id for update;
  if not found then raise invalid_parameter_value using message = 'Season not found.'; end if;
  if target.archived_at is not null then
    raise invalid_parameter_value using message = 'Season is already archived.';
  end if;
  update public.seasons
  set archived_at = clock_timestamp(), archived_by = caller_id
  where id = p_season_id;
  return p_season_id;
end;
$$;

create function public.restore_season(p_season_id uuid)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  target public.seasons%rowtype;
begin
  if caller_id is null or not exists (
    select 1 from public.admin_users where user_id = caller_id
  ) then
    raise insufficient_privilege using message = 'Admin authorization is required.';
  end if;
  select * into target from public.seasons where id = p_season_id for update;
  if not found then raise invalid_parameter_value using message = 'Season not found.'; end if;
  if target.archived_at is null then
    raise invalid_parameter_value using message = 'Season is not archived.';
  end if;
  if not exists (
    select 1 from public.leagues
    where id = target.league_id and archived_at is null
  ) then
    raise invalid_parameter_value using message = 'Restore the league before restoring this season.';
  end if;
  update public.seasons
  set archived_at = null, archived_by = null
  where id = p_season_id;
  return p_season_id;
end;
$$;

revoke execute on function public.create_season(uuid, text, date, date) from public, anon;
revoke execute on function public.complete_season(uuid) from public, anon;
revoke execute on function public.reopen_season(uuid) from public, anon;
revoke execute on function public.archive_season(uuid) from public, anon;
revoke execute on function public.restore_season(uuid) from public, anon;
grant execute on function public.create_season(uuid, text, date, date) to authenticated;
grant execute on function public.complete_season(uuid) to authenticated;
grant execute on function public.reopen_season(uuid) to authenticated;
grant execute on function public.archive_season(uuid) to authenticated;
grant execute on function public.restore_season(uuid) to authenticated;

-- Restoring an unfinished game into a completed season would make the historical
-- season mutable again, so only completed games may be restored there.
create or replace function public.restore_game(p_game_id uuid)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  target public.games%rowtype;
  parent_season public.seasons%rowtype;
begin
  if caller_id is null or not exists (
    select 1 from public.admin_users where user_id = caller_id
  ) then
    raise insufficient_privilege using message = 'Admin authorization is required.';
  end if;
  select * into target from public.games where id = p_game_id for update;
  if not found then raise invalid_parameter_value using message = 'Game not found.'; end if;
  if target.archived_at is null then
    raise invalid_parameter_value using message = 'Game is not archived.';
  end if;
  select * into parent_season from public.seasons where id = target.season_id;
  if parent_season.archived_at is not null then
    raise invalid_parameter_value using message = 'Restore the season before restoring this game.';
  end if;
  if not exists (
    select 1 from public.leagues
    where id = parent_season.league_id and archived_at is null
  ) then
    raise invalid_parameter_value using message = 'Restore the league before restoring this game.';
  end if;
  if not parent_season.active and target.status <> 'completed' then
    raise invalid_parameter_value using message = 'Reopen the season before restoring an unfinished game.';
  end if;
  update public.games set archived_at = null, archived_by = null where id = p_game_id;
  return p_game_id;
end;
$$;

revoke execute on function public.restore_game(uuid) from public, anon;
grant execute on function public.restore_game(uuid) to authenticated;

-- Completed or archived seasons cannot accept new or changed game/scoring data.
create or replace function public.reject_archived_game_write()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  parent_season public.seasons%rowtype;
  parent_league_archived_at timestamptz;
begin
  select * into parent_season from public.seasons where id = new.season_id;
  if not found then return new; end if;
  select archived_at into parent_league_archived_at
  from public.leagues where id = parent_season.league_id;

  if parent_league_archived_at is not null then
    raise invalid_parameter_value using message = 'Archived leagues cannot accept game changes.';
  end if;
  if parent_season.archived_at is not null then
    raise invalid_parameter_value using message = 'Archived seasons cannot accept game changes.';
  end if;
  if not parent_season.active then
    raise invalid_parameter_value using message = 'Completed seasons cannot accept game changes.';
  end if;
  if tg_op = 'UPDATE' and old.archived_at is not null then
    raise invalid_parameter_value using message = 'Archived games cannot be changed.';
  end if;
  return new;
end;
$$;

create or replace function public.reject_archived_plate_appearance_write()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  target_game_id uuid;
begin
  if tg_op = 'DELETE' then target_game_id := old.game_id;
  else target_game_id := new.game_id;
  end if;

  if exists (
    select 1
    from public.games as game
    join public.seasons as season on season.id = game.season_id
    join public.leagues as league on league.id = season.league_id
    where game.id = target_game_id
      and (
        game.archived_at is not null
        or season.archived_at is not null
        or league.archived_at is not null
        or not season.active
      )
  ) then
    raise invalid_parameter_value using message = 'Completed or archived seasons cannot be scored.';
  end if;

  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

comment on column public.seasons.completed_at is
  'When set, the season is historical: visible in stats and history but unavailable for new games.';
comment on column public.seasons.archived_at is
  'When set, the season and its descendants are recoverably hidden from normal reads and statistics.';
comment on function public.create_season(uuid, text, date, date) is
  'Creates an active season and carries forward the latest visible roster after explicit admin authorization.';
comment on function public.complete_season(uuid) is
  'Closes a season only after all visible games are completed; historical statistics remain visible.';
