-- Connected rollback-only validation for admin player and roster management.
begin;

do $$
begin
  if not exists (select 1 from public.admin_users) then
    raise exception 'roster management tests require one public.admin_users row';
  end if;
end;
$$;

select set_config(
  'test.softball_admin_id',
  (select user_id::text from public.admin_users order by created_at limit 1),
  true
);
set local role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.softball_admin_id'), true);

insert into public.leagues (id, name, slug)
values (
  '60000000-0000-4000-8000-000000000001',
  'Roster Management League',
  'roster-management-league'
);

insert into public.seasons (id, league_id, name)
values (
  '60000000-0000-4000-8000-000000000002',
  '60000000-0000-4000-8000-000000000001',
  'Roster Season'
);

insert into public.players (id, first_name, last_name)
values (
  '60000000-0000-4000-8000-000000000003',
  'Existing',
  'Player'
);

do $$
declare
  created_player_id uuid;
  duplicate_name_rejected boolean := false;
  duplicate_roster_rejected boolean := false;
begin
  created_player_id := public.create_player_for_season(
    '60000000-0000-4000-8000-000000000002',
    '  Brand   New   Player '
  );
  perform set_config('test.created_player_id', created_player_id::text, true);

  if not exists (
    select 1 from public.players
    where id = created_player_id
      and display_name = 'Brand New Player'
      and active
  ) or not exists (
    select 1 from public.season_players
    where season_id = '60000000-0000-4000-8000-000000000002'
      and player_id = created_player_id
  ) then
    raise exception 'new player creation was not normalized and rostered atomically';
  end if;

  begin
    perform public.create_player_for_season(
      '60000000-0000-4000-8000-000000000002',
      'brand new player'
    );
  exception when unique_violation then
    duplicate_name_rejected := true;
  end;
  if not duplicate_name_rejected then
    raise exception 'case-insensitive duplicate player name was accepted';
  end if;

  perform public.add_existing_player_to_season(
    '60000000-0000-4000-8000-000000000002',
    '60000000-0000-4000-8000-000000000003'
  );

  begin
    perform public.add_existing_player_to_season(
      '60000000-0000-4000-8000-000000000002',
      '60000000-0000-4000-8000-000000000003'
    );
  exception when unique_violation then
    duplicate_roster_rejected := true;
  end;
  if not duplicate_roster_rejected then
    raise exception 'duplicate season roster membership was accepted';
  end if;

  perform public.remove_player_from_season(
    '60000000-0000-4000-8000-000000000002',
    created_player_id
  );

  if exists (
    select 1 from public.season_players
    where season_id = '60000000-0000-4000-8000-000000000002'
      and player_id = created_player_id
  ) or not exists (
    select 1 from public.players where id = created_player_id
  ) then
    raise exception 'roster removal did not preserve the global player';
  end if;
end;
$$;

insert into public.games (
  id, season_id, played_at, opponent, status, team_score, opponent_score
) values (
  '60000000-0000-4000-8000-000000000004',
  '60000000-0000-4000-8000-000000000002',
  '2026-08-13 19:00:00+00',
  'Roster History Opponent',
  'completed',
  0,
  0
);

insert into public.game_lineup (game_id, season_id, player_id, batting_order)
values (
  '60000000-0000-4000-8000-000000000004',
  '60000000-0000-4000-8000-000000000002',
  '60000000-0000-4000-8000-000000000003',
  1
);

do $$
declare
  history_removal_rejected boolean := false;
begin
  begin
    perform public.remove_player_from_season(
      '60000000-0000-4000-8000-000000000002',
      '60000000-0000-4000-8000-000000000003'
    );
  exception when invalid_parameter_value then
    history_removal_rejected := true;
  end;
  if not history_removal_rejected then
    raise exception 'player with recorded lineup history was removed from the roster';
  end if;
end;
$$;

set local role anon;
select set_config('request.jwt.claim.sub', '', true);
do $$
declare
  action_rejected boolean := false;
begin
  begin
    perform public.create_player_for_season(
      '60000000-0000-4000-8000-000000000002',
      'Anonymous Player'
    );
  exception when insufficient_privilege then
    action_rejected := true;
  end;
  if not action_rejected then raise exception 'anonymous roster write succeeded'; end if;
end;
$$;

set local role authenticated;
select set_config('request.jwt.claim.sub', '99999999-9999-4999-8999-999999999999', true);
do $$
declare
  action_rejected boolean := false;
begin
  begin
    perform public.add_existing_player_to_season(
      '60000000-0000-4000-8000-000000000002',
      '60000000-0000-4000-8000-000000000003'
    );
  exception when insufficient_privilege then
    action_rejected := true;
  end;
  if not action_rejected then raise exception 'non-admin roster write succeeded'; end if;
end;
$$;

rollback;
