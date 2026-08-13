-- Secure admin roster management. Players are global records; roster membership
-- remains season-specific. Every write validates the active visible season and
-- the explicit admin allowlist.

create unique index players_display_name_ci_idx
  on public.players(lower(display_name));

create function public.create_player_for_season(
  p_season_id uuid,
  p_display_name text
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  normalized_name text := regexp_replace(btrim(coalesce(p_display_name, '')), '\s+', ' ', 'g');
  created_player_id uuid;
begin
  if caller_id is null or not exists (
    select 1 from public.admin_users where user_id = caller_id
  ) then
    raise insufficient_privilege using message = 'Admin authorization is required.';
  end if;

  if normalized_name = '' or char_length(normalized_name) > 100 then
    raise invalid_parameter_value using
      message = 'Enter a player name of 100 characters or fewer.';
  end if;

  if not exists (
    select 1
    from public.seasons as season
    join public.leagues as league on league.id = season.league_id
    where season.id = p_season_id
      and season.active
      and season.archived_at is null
      and league.active
      and league.archived_at is null
  ) then
    raise invalid_parameter_value using
      message = 'Choose a current season in an active league.';
  end if;

  if exists (
    select 1 from public.players
    where lower(display_name) = lower(normalized_name)
  ) then
    raise unique_violation using
      message = 'A player with this name already exists. Choose played in another league.';
  end if;

  insert into public.players (first_name, last_name)
  values (normalized_name, '')
  returning id into created_player_id;

  insert into public.season_players (season_id, player_id)
  values (p_season_id, created_player_id);

  return created_player_id;
exception
  when unique_violation then
    raise unique_violation using
      message = 'A player with this name already exists. Choose played in another league.';
end;
$$;

create function public.add_existing_player_to_season(
  p_season_id uuid,
  p_player_id uuid
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
begin
  if caller_id is null or not exists (
    select 1 from public.admin_users where user_id = caller_id
  ) then
    raise insufficient_privilege using message = 'Admin authorization is required.';
  end if;

  if not exists (
    select 1
    from public.seasons as season
    join public.leagues as league on league.id = season.league_id
    where season.id = p_season_id
      and season.active
      and season.archived_at is null
      and league.active
      and league.archived_at is null
  ) then
    raise invalid_parameter_value using
      message = 'Choose a current season in an active league.';
  end if;

  if not exists (
    select 1 from public.players where id = p_player_id and active
  ) then
    raise invalid_parameter_value using message = 'Choose an active player.';
  end if;

  insert into public.season_players (season_id, player_id)
  values (p_season_id, p_player_id);

  return p_player_id;
exception
  when unique_violation then
    raise unique_violation using message = 'This player is already on the season roster.';
end;
$$;

create function public.remove_player_from_season(
  p_season_id uuid,
  p_player_id uuid
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
begin
  if caller_id is null or not exists (
    select 1 from public.admin_users where user_id = caller_id
  ) then
    raise insufficient_privilege using message = 'Admin authorization is required.';
  end if;

  if not exists (
    select 1
    from public.seasons as season
    join public.leagues as league on league.id = season.league_id
    where season.id = p_season_id
      and season.active
      and season.archived_at is null
      and league.active
      and league.archived_at is null
  ) then
    raise invalid_parameter_value using
      message = 'Choose a current season in an active league.';
  end if;

  if exists (
    select 1 from public.game_lineup
    where season_id = p_season_id and player_id = p_player_id
  ) then
    raise invalid_parameter_value using
      message = 'This player has recorded game history in the season and cannot be removed.';
  end if;

  delete from public.season_players
  where season_id = p_season_id and player_id = p_player_id;

  if not found then
    raise invalid_parameter_value using message = 'This player is not on the season roster.';
  end if;

  return p_player_id;
end;
$$;

revoke execute on function public.create_player_for_season(uuid, text)
  from public, anon;
revoke execute on function public.add_existing_player_to_season(uuid, uuid)
  from public, anon;
revoke execute on function public.remove_player_from_season(uuid, uuid)
  from public, anon;
grant execute on function public.create_player_for_season(uuid, text)
  to authenticated;
grant execute on function public.add_existing_player_to_season(uuid, uuid)
  to authenticated;
grant execute on function public.remove_player_from_season(uuid, uuid)
  to authenticated;

comment on function public.create_player_for_season(uuid, text) is
  'Creates one global player and adds that player to a current season roster after admin authorization.';
comment on function public.add_existing_player_to_season(uuid, uuid) is
  'Adds an active global player to a current season roster after admin authorization.';
comment on function public.remove_player_from_season(uuid, uuid) is
  'Removes an unused player from a current season roster while preserving all recorded game history.';
