-- Connected rollback-only validation for recoverable game and league archives.
-- Requires one enrolled admin user. No fixture rows survive this transaction.
begin;

do $$
begin
  if not exists (select 1 from public.admin_users) then
    raise exception 'archive tests require one public.admin_users row';
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
values ('20000000-0000-4000-8000-000000000001', 'Archive Test League', 'archive-test-league');

insert into public.seasons (id, league_id, name, start_date, end_date)
values (
  '20000000-0000-4000-8000-000000000101',
  '20000000-0000-4000-8000-000000000001',
  'Archive Test Season',
  '2026-03-01',
  '2026-04-01'
);

insert into public.players (id, first_name, last_name)
values
  ('20000000-0000-4000-8000-000000001001', 'Archive', 'Ada'),
  ('20000000-0000-4000-8000-000000001002', 'Archive', 'Betty');

insert into public.season_players (season_id, player_id)
values
  ('20000000-0000-4000-8000-000000000101', '20000000-0000-4000-8000-000000001001'),
  ('20000000-0000-4000-8000-000000000101', '20000000-0000-4000-8000-000000001002');

do $$
<<test>>
declare
  game_a uuid;
  game_b uuid;
  state_token timestamptz;
  saved_state public.game_states%rowtype;
  rejected_count integer := 0;
begin
  game_a := public.create_game_with_lineup(
    '20000000-0000-4000-8000-000000000001',
    '20000000-0000-4000-8000-000000000101',
    'Archive In Progress',
    '2026-03-10 16:00:00+00',
    array[
      '20000000-0000-4000-8000-000000001001'::uuid,
      '20000000-0000-4000-8000-000000001002'::uuid
    ]
  );
  perform set_config('test.archive_game_a', game_a::text, true);

  select updated_at into state_token
  from public.game_states where game_id = game_a;

  perform public.record_plate_appearance(
    game_a,
    'single',
    0::smallint,
    0::smallint,
    jsonb_build_array(jsonb_build_object(
      'player_id', '20000000-0000-4000-8000-000000001001',
      'starting_base', 'batter',
      'ending_base', 'first'
    )),
    state_token
  );

  game_b := public.create_game_with_lineup(
    '20000000-0000-4000-8000-000000000001',
    '20000000-0000-4000-8000-000000000101',
    'Archive Completed',
    '2026-03-17 16:00:00+00',
    array[
      '20000000-0000-4000-8000-000000001001'::uuid,
      '20000000-0000-4000-8000-000000001002'::uuid
    ]
  );
  perform set_config('test.archive_game_b', game_b::text, true);

  select updated_at into state_token
  from public.game_states where game_id = game_b;

  perform public.record_plate_appearance(
    game_b,
    'single',
    0::smallint,
    0::smallint,
    jsonb_build_array(jsonb_build_object(
      'player_id', '20000000-0000-4000-8000-000000001001',
      'starting_base', 'batter',
      'ending_base', 'first'
    )),
    state_token
  );

  select updated_at into state_token
  from public.game_states where game_id = game_b;

  perform public.record_plate_appearance(
    game_b,
    'home_run',
    0::smallint,
    2::smallint,
    jsonb_build_array(
      jsonb_build_object(
        'player_id', '20000000-0000-4000-8000-000000001001',
        'starting_base', 'first',
        'ending_base', 'home'
      ),
      jsonb_build_object(
        'player_id', '20000000-0000-4000-8000-000000001002',
        'starting_base', 'batter',
        'ending_base', 'home'
      )
    ),
    state_token
  );

  select updated_at into state_token
  from public.game_states where game_id = game_b;
  perform public.finish_game(game_b, state_token);

  if not exists (
    select 1 from public.season_batting_stats
    where season_id = '20000000-0000-4000-8000-000000000101'
      and player_id = '20000000-0000-4000-8000-000000001001'
      and games = 2 and plate_appearances = 2 and hits = 2
  ) then
    raise exception 'baseline archive statistics are incorrect';
  end if;

  perform public.archive_game(game_b);

  if not exists (
    select 1 from public.games
    where id = game_b
      and archived_at is not null
      and archived_by = current_setting('test.softball_admin_id')::uuid
  )
    or (select count(*) from public.plate_appearances where game_id = game_b) <> 2
    or (select count(*) from public.runner_advancements as advancement
        join public.plate_appearances as appearance
          on appearance.id = advancement.plate_appearance_id
        where appearance.game_id = game_b) <> 3
    or not exists (
      select 1 from public.season_batting_stats
      where season_id = '20000000-0000-4000-8000-000000000101'
        and player_id = '20000000-0000-4000-8000-000000001001'
        and games = 1 and plate_appearances = 1 and hits = 1
    )
  then
    raise exception 'game archive did not preserve events while removing statistics';
  end if;

  perform public.restore_game(game_b);

  if not exists (
    select 1 from public.season_batting_stats
    where season_id = '20000000-0000-4000-8000-000000000101'
      and player_id = '20000000-0000-4000-8000-000000001001'
      and games = 2 and plate_appearances = 2 and hits = 2
  ) then
    raise exception 'restoring a game did not restore its statistics';
  end if;

  select * into strict saved_state
  from public.game_states where game_id = game_a;

  perform public.archive_game(game_a);

  if exists (
    select 1 from public.games
    where id = game_a and status = 'in_progress' and archived_at is null
  ) then
    raise exception 'archived in-progress game still appears in the normal in-progress query';
  end if;

  begin
    perform public.record_plate_appearance(
      game_a,
      'walk',
      0::smallint,
      0::smallint,
      jsonb_build_array(
        jsonb_build_object(
          'player_id', '20000000-0000-4000-8000-000000001001',
          'starting_base', 'first',
          'ending_base', 'second'
        ),
        jsonb_build_object(
          'player_id', '20000000-0000-4000-8000-000000001002',
          'starting_base', 'batter',
          'ending_base', 'first'
        )
      ),
      saved_state.updated_at
    );
  exception when invalid_parameter_value then
    rejected_count := rejected_count + 1;
  end;

  begin
    perform public.undo_last_plate_appearance(game_a, saved_state.updated_at);
  exception when invalid_parameter_value then
    rejected_count := rejected_count + 1;
  end;

  begin
    perform public.finish_game(game_a, saved_state.updated_at);
  exception when invalid_parameter_value then
    rejected_count := rejected_count + 1;
  end;

  if rejected_count <> 3 then
    raise exception 'archived in-progress game accepted a scoring mutation';
  end if;

  perform public.restore_game(game_a);

  if not exists (
    select 1 from public.game_states
    where game_id = game_a
      and inning = saved_state.inning
      and outs = saved_state.outs
      and next_batter_order = saved_state.next_batter_order
      and first_base_player_id is not distinct from saved_state.first_base_player_id
      and second_base_player_id is not distinct from saved_state.second_base_player_id
      and third_base_player_id is not distinct from saved_state.third_base_player_id
      and updated_at = saved_state.updated_at
  ) then
    raise exception 'game restore changed the resumable state';
  end if;

  perform public.record_plate_appearance(
    game_a,
    'walk',
    0::smallint,
    0::smallint,
    jsonb_build_array(
      jsonb_build_object(
        'player_id', '20000000-0000-4000-8000-000000001001',
        'starting_base', 'first',
        'ending_base', 'second'
      ),
      jsonb_build_object(
        'player_id', '20000000-0000-4000-8000-000000001002',
        'starting_base', 'batter',
        'ending_base', 'first'
      )
    ),
    saved_state.updated_at
  );

  select updated_at into state_token
  from public.game_states where game_id = game_a;
  perform public.undo_last_plate_appearance(game_a, state_token);

  begin
    delete from public.games where id = game_a;
  exception when insufficient_privilege then
    rejected_count := rejected_count + 1;
  end;

  begin
    delete from public.leagues
    where id = '20000000-0000-4000-8000-000000000001';
  exception when insufficient_privilege then
    rejected_count := rejected_count + 1;
  end;

  if rejected_count <> 5 then
    raise exception 'authenticated API still permits hard deletion';
  end if;

  perform public.archive_game(game_b);
  perform set_config(
    'test.game_b_archived_at',
    (select archived_at::text from public.games where id = game_b),
    true
  );
  perform public.archive_league('20000000-0000-4000-8000-000000000001');

  if exists (
    select 1 from public.season_batting_stats
    where season_id = '20000000-0000-4000-8000-000000000101'
  )
    or (select archived_at from public.games where id = game_a) is not null
    or (select archived_at::text from public.games where id = game_b)
      <> current_setting('test.game_b_archived_at')
  then
    raise exception 'league archive rewrote children or left statistics visible';
  end if;
end;
$$;

-- Anonymous visitors cannot see archived branches or execute archive operations.
set local role anon;
select set_config('request.jwt.claim.sub', '', true);
do $$
declare
  rejected_count integer := 0;
begin
  if (select count(*) from public.leagues
      where id = '20000000-0000-4000-8000-000000000001') <> 0
    or (select count(*) from public.seasons
        where id = '20000000-0000-4000-8000-000000000101') <> 0
    or (select count(*) from public.games
        where id in (
          current_setting('test.archive_game_a')::uuid,
          current_setting('test.archive_game_b')::uuid
        )) <> 0
    or (select count(*) from public.plate_appearances
        where game_id = current_setting('test.archive_game_a')::uuid) <> 0
  then
    raise exception 'anonymous reads exposed an archived league branch';
  end if;

  begin
    perform public.archive_game(current_setting('test.archive_game_a')::uuid);
  exception when insufficient_privilege then
    rejected_count := rejected_count + 1;
  end;

  begin
    perform public.restore_league('20000000-0000-4000-8000-000000000001');
  exception when insufficient_privilege then
    rejected_count := rejected_count + 1;
  end;

  if rejected_count <> 2 then
    raise exception 'anonymous archive function execution unexpectedly succeeded';
  end if;
end;
$$;

-- Authenticated non-admin callers fail the explicit allowlist check on all RPCs.
set local role authenticated;
select set_config('request.jwt.claim.sub', '99999999-9999-4999-8999-999999999999', true);
do $$
declare
  rejected_count integer := 0;
begin
  begin
    perform public.archive_game(current_setting('test.archive_game_a')::uuid);
  exception when insufficient_privilege then
    rejected_count := rejected_count + 1;
  end;
  begin
    perform public.restore_game(current_setting('test.archive_game_b')::uuid);
  exception when insufficient_privilege then
    rejected_count := rejected_count + 1;
  end;
  begin
    perform public.archive_league('20000000-0000-4000-8000-000000000001');
  exception when insufficient_privilege then
    rejected_count := rejected_count + 1;
  end;
  begin
    perform public.restore_league('20000000-0000-4000-8000-000000000001');
  exception when insufficient_privilege then
    rejected_count := rejected_count + 1;
  end;

  if rejected_count <> 4 then
    raise exception 'authenticated non-admin archive operation unexpectedly succeeded';
  end if;
end;
$$;

-- Restoring a league reveals only children that were not independently archived.
select set_config('request.jwt.claim.sub', current_setting('test.softball_admin_id'), true);
do $$
begin
  perform public.restore_league('20000000-0000-4000-8000-000000000001');

  if (select archived_at from public.games
      where id = current_setting('test.archive_game_a')::uuid) is not null
    or (select archived_at::text from public.games
        where id = current_setting('test.archive_game_b')::uuid)
      <> current_setting('test.game_b_archived_at')
    or not exists (
      select 1 from public.season_batting_stats
      where season_id = '20000000-0000-4000-8000-000000000101'
        and player_id = '20000000-0000-4000-8000-000000001001'
        and games = 1 and plate_appearances = 1 and hits = 1
    )
  then
    raise exception 'league restore changed an independent game archive';
  end if;

  perform public.restore_game(current_setting('test.archive_game_b')::uuid);

  if not exists (
    select 1 from public.season_batting_stats
    where season_id = '20000000-0000-4000-8000-000000000101'
      and player_id = '20000000-0000-4000-8000-000000001001'
      and games = 2 and plate_appearances = 2 and hits = 2
  ) then
    raise exception 'independent game restore did not return complete statistics';
  end if;
end;
$$;

rollback;
