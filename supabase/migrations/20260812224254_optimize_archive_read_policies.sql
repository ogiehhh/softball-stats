-- Keep anonymous visibility checks independent of the admin allowlist, while
-- consolidating authenticated reads into one policy per table. This avoids
-- multiple permissive policies without weakening archive visibility.

create index leagues_archived_by_idx on public.leagues(archived_by);
create index games_archived_by_idx on public.games(archived_by);

alter policy visible_read on public.leagues to anon;
drop policy admin_read_archived on public.leagues;
create policy authenticated_read
on public.leagues
for select
to authenticated
using (
  archived_at is null
  or exists (
    select 1 from public.admin_users
    where user_id = (select auth.uid())
  )
);

alter policy visible_read on public.seasons to anon;
drop policy admin_read_archived on public.seasons;
create policy authenticated_read
on public.seasons
for select
to authenticated
using (
  exists (
    select 1
    from public.leagues as league
    where league.id = league_id
      and league.archived_at is null
  )
  or exists (
    select 1 from public.admin_users
    where user_id = (select auth.uid())
  )
);

alter policy visible_read on public.season_players to anon;
drop policy admin_read_archived on public.season_players;
create policy authenticated_read
on public.season_players
for select
to authenticated
using (
  exists (
    select 1
    from public.seasons as season
    join public.leagues as league on league.id = season.league_id
    where season.id = season_id
      and league.archived_at is null
  )
  or exists (
    select 1 from public.admin_users
    where user_id = (select auth.uid())
  )
);

alter policy visible_read on public.games to anon;
drop policy admin_read_archived on public.games;
create policy authenticated_read
on public.games
for select
to authenticated
using (
  (
    archived_at is null
    and exists (
      select 1
      from public.seasons as season
      join public.leagues as league on league.id = season.league_id
      where season.id = season_id
        and league.archived_at is null
    )
  )
  or exists (
    select 1 from public.admin_users
    where user_id = (select auth.uid())
  )
);

alter policy visible_read on public.game_lineup to anon;
drop policy admin_read_archived on public.game_lineup;
create policy authenticated_read
on public.game_lineup
for select
to authenticated
using (
  exists (
    select 1
    from public.games as game
    join public.seasons as season on season.id = game.season_id
    join public.leagues as league on league.id = season.league_id
    where game.id = game_id
      and game.archived_at is null
      and league.archived_at is null
  )
  or exists (
    select 1 from public.admin_users
    where user_id = (select auth.uid())
  )
);

alter policy visible_read on public.game_states to anon;
drop policy admin_read_archived on public.game_states;
create policy authenticated_read
on public.game_states
for select
to authenticated
using (
  exists (
    select 1
    from public.games as game
    join public.seasons as season on season.id = game.season_id
    join public.leagues as league on league.id = season.league_id
    where game.id = game_id
      and game.archived_at is null
      and league.archived_at is null
  )
  or exists (
    select 1 from public.admin_users
    where user_id = (select auth.uid())
  )
);

alter policy visible_read on public.plate_appearances to anon;
drop policy admin_read_archived on public.plate_appearances;
create policy authenticated_read
on public.plate_appearances
for select
to authenticated
using (
  exists (
    select 1
    from public.games as game
    join public.seasons as season on season.id = game.season_id
    join public.leagues as league on league.id = season.league_id
    where game.id = game_id
      and game.archived_at is null
      and league.archived_at is null
  )
  or exists (
    select 1 from public.admin_users
    where user_id = (select auth.uid())
  )
);

alter policy visible_read on public.runner_advancements to anon;
drop policy admin_read_archived on public.runner_advancements;
create policy authenticated_read
on public.runner_advancements
for select
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
      and league.archived_at is null
  )
  or exists (
    select 1 from public.admin_users
    where user_id = (select auth.uid())
  )
);
