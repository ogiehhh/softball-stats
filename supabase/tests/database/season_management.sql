-- Connected rollback-only validation for season creation, completion, archive,
-- historical statistics, scorer visibility, and authorization boundaries.
begin;

do $$
begin
  if not exists (select 1 from public.admin_users) then
    raise exception 'season management tests require one public.admin_users row';
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
  '50000000-0000-4000-8000-000000000001',
  'Season Management League',
  'season-management-league'
);

insert into public.players (id, first_name, last_name)
values ('50000000-0000-4000-8000-000000000002', 'Season', 'Tester');

insert into public.seasons (id, league_id, name, start_date, end_date)
values (
  '50000000-0000-4000-8000-000000000003',
  '50000000-0000-4000-8000-000000000001',
  'Spring 2026',
  '2026-03-01',
  '2026-05-31'
);

insert into public.season_players (season_id, player_id)
values (
  '50000000-0000-4000-8000-000000000003',
  '50000000-0000-4000-8000-000000000002'
);

do $$
declare
  historical_id uuid;
  current_id uuid;
  duplicate_rejected boolean := false;
  invalid_dates_rejected boolean := false;
begin
  historical_id := public.create_season(
    '50000000-0000-4000-8000-000000000001',
    '  Summer   2026  ',
    '2026-06-01',
    '2026-08-15'
  );
  perform set_config('test.historical_season_id', historical_id::text, true);

  if not exists (
    select 1 from public.seasons
    where id = historical_id
      and name = 'Summer 2026'
      and active
      and completed_at is null
      and archived_at is null
  ) then
    raise exception 'season creation did not normalize and persist an active season';
  end if;

  if not exists (
    select 1 from public.season_players
    where season_id = historical_id
      and player_id = '50000000-0000-4000-8000-000000000002'
  ) then
    raise exception 'season creation did not carry forward the latest league roster';
  end if;

  begin
    perform public.create_season(
      '50000000-0000-4000-8000-000000000001',
      'summer 2026',
      null,
      null
    );
  exception when unique_violation then
    duplicate_rejected := true;
  end;
  if not duplicate_rejected then raise exception 'duplicate season name was accepted'; end if;

  begin
    perform public.create_season(
      '50000000-0000-4000-8000-000000000001',
      'Bad Dates',
      '2026-09-02',
      '2026-09-01'
    );
  exception when invalid_parameter_value then
    invalid_dates_rejected := true;
  end;
  if not invalid_dates_rejected then raise exception 'reversed season dates were accepted'; end if;

  perform public.update_season_dates(
    historical_id,
    '2026-06-05',
    '2026-08-20'
  );
  if not exists (
    select 1 from public.seasons
    where id = historical_id
      and start_date = '2026-06-05'
      and end_date = '2026-08-20'
  ) then
    raise exception 'season date editing did not persist both dates';
  end if;

  invalid_dates_rejected := false;
  begin
    perform public.update_season_dates(
      historical_id,
      '2026-08-21',
      '2026-08-20'
    );
  exception when invalid_parameter_value then
    invalid_dates_rejected := true;
  end;
  if not invalid_dates_rejected then raise exception 'reversed edited dates were accepted'; end if;

  insert into public.games (id, season_id, played_at, opponent, status, team_score, opponent_score)
  values (
    '50000000-0000-4000-8000-000000000004',
    historical_id,
    '2026-07-01 19:00:00+00',
    'History Opponent',
    'completed',
    0,
    0
  );

  insert into public.game_lineup (game_id, season_id, player_id, batting_order)
  values (
    '50000000-0000-4000-8000-000000000004',
    historical_id,
    '50000000-0000-4000-8000-000000000002',
    1
  );

  insert into public.plate_appearances (
    id, game_id, player_id, sequence_no, inning, outs_before, result, outs_recorded, rbi
  ) values (
    '50000000-0000-4000-8000-000000000005',
    '50000000-0000-4000-8000-000000000004',
    '50000000-0000-4000-8000-000000000002',
    1,
    1,
    0,
    'single',
    0,
    0
  );

  perform public.complete_season(historical_id);

  if not exists (
    select 1 from public.seasons
    where id = historical_id
      and not active
      and completed_at is not null
      and completed_by = current_setting('test.softball_admin_id')::uuid
  ) then
    raise exception 'season completion did not preserve an auditable completed state';
  end if;

  if not exists (
    select 1 from public.season_batting_stats
    where season_id = historical_id
      and player_id = '50000000-0000-4000-8000-000000000002'
      and hits = 1
  ) then
    raise exception 'completed season statistics disappeared from history';
  end if;

  current_id := public.create_season(
    '50000000-0000-4000-8000-000000000001',
    'Fall 2026',
    '2026-09-01',
    '2026-11-30'
  );
  perform set_config('test.current_season_id', current_id::text, true);

  if (select hits from public.season_batting_stats
      where season_id = current_id
        and player_id = '50000000-0000-4000-8000-000000000002') <> 0 then
    raise exception 'historical hits leaked into current-season statistics';
  end if;

  if (select sum(hits) from public.season_batting_stats
      where league_id = '50000000-0000-4000-8000-000000000001'
        and player_id = '50000000-0000-4000-8000-000000000002') <> 1 then
    raise exception 'completed season did not contribute to league all-time statistics';
  end if;

  insert into public.games (id, season_id, played_at, opponent, status, team_score)
  values (
    '50000000-0000-4000-8000-000000000006',
    current_id,
    '2026-09-10 19:00:00+00',
    'Unfinished Opponent',
    'in_progress',
    0
  );

  begin
    perform public.complete_season(current_id);
    raise exception 'season completion unexpectedly accepted an unfinished game';
  exception when invalid_parameter_value then
    null;
  end;

  perform public.archive_season(historical_id);

  if exists (select 1 from public.season_batting_stats where season_id = historical_id) then
    raise exception 'archived season remains in statistics';
  end if;

  if (select sum(hits) from public.season_batting_stats
      where league_id = '50000000-0000-4000-8000-000000000001'
        and player_id = '50000000-0000-4000-8000-000000000002') <> 0 then
    raise exception 'archived season remains in league all-time statistics';
  end if;
end;
$$;

-- Anonymous callers cannot see an archived season or invoke lifecycle writes.
set local role anon;
select set_config('request.jwt.claim.sub', '', true);
do $$
declare
  action_rejected boolean := false;
begin
  if exists (
    select 1 from public.seasons
    where id = current_setting('test.historical_season_id')::uuid
  ) then
    raise exception 'anonymous read exposed an archived season';
  end if;

  begin
    perform public.create_season(
      '50000000-0000-4000-8000-000000000001', 'Anonymous Season', null, null
    );
  exception when insufficient_privilege then
    action_rejected := true;
  end;
  if not action_rejected then raise exception 'anonymous season creation succeeded'; end if;

  action_rejected := false;
  begin
    perform public.update_season_dates(
      current_setting('test.current_season_id')::uuid, null, null
    );
  exception when insufficient_privilege then
    action_rejected := true;
  end;
  if not action_rejected then raise exception 'anonymous season date edit succeeded'; end if;
end;
$$;

-- Authentication without admin enrollment is also denied.
set local role authenticated;
select set_config('request.jwt.claim.sub', '99999999-9999-4999-8999-999999999999', true);
do $$
declare
  action_rejected boolean := false;
begin
  begin
    perform public.archive_season(current_setting('test.current_season_id')::uuid);
  exception when insufficient_privilege then
    action_rejected := true;
  end;
  if not action_rejected then raise exception 'non-admin season archive succeeded'; end if;

  action_rejected := false;
  begin
    perform public.update_season_dates(
      current_setting('test.current_season_id')::uuid, '2026-09-02', '2026-11-30'
    );
  exception when insufficient_privilege then
    action_rejected := true;
  end;
  if not action_rejected then raise exception 'non-admin season date edit succeeded'; end if;
end;
$$;

-- Restore preserves completion and history; reopening explicitly makes it current again.
select set_config('request.jwt.claim.sub', current_setting('test.softball_admin_id'), true);
do $$
declare
  hard_delete_rejected boolean := false;
begin
  perform public.restore_season(current_setting('test.historical_season_id')::uuid);

  if not exists (
    select 1 from public.seasons
    where id = current_setting('test.historical_season_id')::uuid
      and not active
      and completed_at is not null
      and archived_at is null
  ) then
    raise exception 'restore did not preserve the season completion state';
  end if;

  if not exists (
    select 1 from public.season_batting_stats
    where season_id = current_setting('test.historical_season_id')::uuid and hits = 1
  ) then
    raise exception 'restore did not recover historical season statistics';
  end if;

  perform public.reopen_season(current_setting('test.historical_season_id')::uuid);
  if not exists (
    select 1 from public.seasons
    where id = current_setting('test.historical_season_id')::uuid
      and active and completed_at is null and completed_by is null
  ) then
    raise exception 'reopen did not make the completed season current again';
  end if;

  begin
    delete from public.seasons
    where id = current_setting('test.historical_season_id')::uuid;
  exception when insufficient_privilege then
    hard_delete_rejected := true;
  end;
  if not hard_delete_rejected then raise exception 'authenticated hard delete was permitted'; end if;
end;
$$;

rollback;
