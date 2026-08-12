-- Connected-development validation for the atomic live-scoring RPCs.
-- Requires the deterministic seed and one enrolled admin user. Every write is rolled back.

do $$
begin
  if not exists (select 1 from public.admin_users) then
    raise exception 'live scoring tests require one public.admin_users row';
  end if;
end;
$$;

-- The prescribed six-play inning stays synchronized across events, runner movements,
-- batting order, bases, inning/outs, score, statistics, undo, replay, and completion.
begin;
select set_config(
  'test.softball_admin_id',
  (select user_id::text from public.admin_users order by created_at limit 1),
  true
);
set local role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.softball_admin_id'), true);

do $$
<<test>>
declare
  game_id uuid;
  state_updated_at timestamptz;
  old_state_updated_at timestamptz;
  undone_appearance_id uuid;
  ada_pa_before integer;
  ada_hits_before integer;
  ada_rbi_before integer;
  ada_runs_before integer;
begin
  select plate_appearances, hits, rbi, runs
  into ada_pa_before, ada_hits_before, ada_rbi_before, ada_runs_before
  from public.season_batting_stats
  where season_id = '00000000-0000-4000-8000-000000000101'
    and player_id = '00000000-0000-4000-8000-000000001001';

  game_id := public.create_game_with_lineup(
    '00000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-000000000101',
    'Live Scoring Sequence Test',
    '2026-10-02 16:00:00+00',
    array[
      '00000000-0000-4000-8000-000000001001'::uuid,
      '00000000-0000-4000-8000-000000001002'::uuid,
      '00000000-0000-4000-8000-000000001003'::uuid,
      '00000000-0000-4000-8000-000000001004'::uuid
    ]
  );

  select state.updated_at into state_updated_at
  from public.game_states as state where state.game_id = test.game_id;
  old_state_updated_at := state_updated_at - interval '1 second';

  -- Ada singles.
  perform public.record_plate_appearance(
    game_id,
    'single',
    0::smallint,
    0::smallint,
    jsonb_build_array(jsonb_build_object(
      'player_id', '00000000-0000-4000-8000-000000001001',
      'starting_base', 'batter',
      'ending_base', 'first'
    )),
    state_updated_at
  );

  select state.updated_at into state_updated_at
  from public.game_states as state where state.game_id = test.game_id;

  -- A stale browser cannot append a second event from the old snapshot.
  begin
    perform public.record_plate_appearance(
      game_id,
      'walk',
      0::smallint,
      0::smallint,
      jsonb_build_array(
        jsonb_build_object(
          'player_id', '00000000-0000-4000-8000-000000001001',
          'starting_base', 'first',
          'ending_base', 'second'
        ),
        jsonb_build_object(
          'player_id', '00000000-0000-4000-8000-000000001002',
          'starting_base', 'batter',
          'ending_base', 'first'
        )
      ),
      old_state_updated_at
    );
    raise exception 'stale scoring unexpectedly succeeded';
  exception when serialization_failure then
    null;
  end;

  if (select count(*) from public.plate_appearances as appearance
      where appearance.game_id = test.game_id) <> 1 then
    raise exception 'stale scoring left a partial plate appearance';
  end if;

  -- Betty walks.
  perform public.record_plate_appearance(
    game_id,
    'walk',
    0::smallint,
    0::smallint,
    jsonb_build_array(
      jsonb_build_object(
        'player_id', '00000000-0000-4000-8000-000000001001',
        'starting_base', 'first',
        'ending_base', 'second'
      ),
      jsonb_build_object(
        'player_id', '00000000-0000-4000-8000-000000001002',
        'starting_base', 'batter',
        'ending_base', 'first'
      )
    ),
    state_updated_at
  );

  select state.updated_at into state_updated_at
  from public.game_states as state where state.game_id = test.game_id;

  -- Carla doubles, scoring Ada and sending Betty to third.
  perform public.record_plate_appearance(
    game_id,
    'double',
    0::smallint,
    1::smallint,
    jsonb_build_array(
      jsonb_build_object(
        'player_id', '00000000-0000-4000-8000-000000001002',
        'starting_base', 'first',
        'ending_base', 'third'
      ),
      jsonb_build_object(
        'player_id', '00000000-0000-4000-8000-000000001001',
        'starting_base', 'second',
        'ending_base', 'home'
      ),
      jsonb_build_object(
        'player_id', '00000000-0000-4000-8000-000000001003',
        'starting_base', 'batter',
        'ending_base', 'second'
      )
    ),
    state_updated_at
  );

  select state.updated_at into state_updated_at
  from public.game_states as state where state.game_id = test.game_id;

  -- Dani grounds out; Betty scores and Carla takes third.
  perform public.record_plate_appearance(
    game_id,
    'groundout',
    1::smallint,
    1::smallint,
    jsonb_build_array(
      jsonb_build_object(
        'player_id', '00000000-0000-4000-8000-000000001003',
        'starting_base', 'second',
        'ending_base', 'third'
      ),
      jsonb_build_object(
        'player_id', '00000000-0000-4000-8000-000000001002',
        'starting_base', 'third',
        'ending_base', 'home'
      ),
      jsonb_build_object(
        'player_id', '00000000-0000-4000-8000-000000001004',
        'starting_base', 'batter',
        'ending_base', 'out'
      )
    ),
    state_updated_at
  );

  select state.updated_at into state_updated_at
  from public.game_states as state where state.game_id = test.game_id;

  -- Ada's sacrifice fly scores Carla.
  perform public.record_plate_appearance(
    game_id,
    'sacrifice_fly',
    1::smallint,
    1::smallint,
    jsonb_build_array(
      jsonb_build_object(
        'player_id', '00000000-0000-4000-8000-000000001003',
        'starting_base', 'third',
        'ending_base', 'home'
      ),
      jsonb_build_object(
        'player_id', '00000000-0000-4000-8000-000000001001',
        'starting_base', 'batter',
        'ending_base', 'out'
      )
    ),
    state_updated_at
  );

  select state.updated_at into state_updated_at
  from public.game_states as state where state.game_id = test.game_id;

  -- Betty strikes out for the third out.
  perform public.record_plate_appearance(
    game_id,
    'strikeout',
    1::smallint,
    0::smallint,
    jsonb_build_array(jsonb_build_object(
      'player_id', '00000000-0000-4000-8000-000000001002',
      'starting_base', 'batter',
      'ending_base', 'out'
    )),
    state_updated_at
  );

  select state.updated_at into state_updated_at
  from public.game_states as state where state.game_id = test.game_id;

  if not exists (
    select 1
    from public.game_states as state
    where state.game_id = test.game_id
      and inning = 2
      and outs = 0
      and next_batter_order = 3
      and first_base_player_id is null
      and second_base_player_id is null
      and third_base_player_id is null
  )
    or (select team_score from public.games where id = game_id) <> 3
    or (select count(*) from public.plate_appearances as appearance
        where appearance.game_id = test.game_id) <> 6
    or (select max(appearance.sequence_no) from public.plate_appearances as appearance
        where appearance.game_id = test.game_id) <> 6
    or (select count(*) from public.runner_advancements advancement
        join public.plate_appearances appearance on appearance.id = advancement.plate_appearance_id
        where appearance.game_id = test.game_id and advancement.ending_base = 'home') <> 3
  then
    raise exception 'six-play sequence did not leave the expected synchronized state';
  end if;

  if not exists (
    select 1
    from public.season_batting_stats
    where season_id = '00000000-0000-4000-8000-000000000101'
      and player_id = '00000000-0000-4000-8000-000000001001'
      and plate_appearances = ada_pa_before + 2
      and hits = ada_hits_before + 1
      and rbi = ada_rbi_before + 1
      and runs = ada_runs_before + 1
  ) then
    raise exception 'live events did not immediately update public season statistics';
  end if;

  undone_appearance_id := public.undo_last_plate_appearance(game_id, state_updated_at);
  select state.updated_at into state_updated_at
  from public.game_states as state where state.game_id = test.game_id;

  if undone_appearance_id is null
    or exists (select 1 from public.plate_appearances where id = undone_appearance_id)
    or not exists (
      select 1
      from public.game_states as state
      where state.game_id = test.game_id
        and inning = 1
        and outs = 2
        and next_batter_order = 2
        and first_base_player_id is null
        and second_base_player_id is null
        and third_base_player_id is null
    )
    or (select team_score from public.games where id = game_id) <> 3
    or (select count(*) from public.plate_appearances as appearance
        where appearance.game_id = test.game_id) <> 5
  then
    raise exception 'undo did not restore the exact pre-strikeout state';
  end if;

  perform public.record_plate_appearance(
    game_id,
    'strikeout',
    1::smallint,
    0::smallint,
    jsonb_build_array(jsonb_build_object(
      'player_id', '00000000-0000-4000-8000-000000001002',
      'starting_base', 'batter',
      'ending_base', 'out'
    )),
    state_updated_at
  );

  select state.updated_at into state_updated_at
  from public.game_states as state where state.game_id = test.game_id;
  perform public.finish_game(game_id, state_updated_at);

  if not exists (
    select 1 from public.games
    where id = game_id and status = 'completed' and team_score = 3
  ) then
    raise exception 'finishing did not persist completed status and final score';
  end if;
end;
$$;
rollback;

-- A home run records the batter as a run and a one-run score in one call.
begin;
select set_config(
  'test.softball_admin_id',
  (select user_id::text from public.admin_users order by created_at limit 1),
  true
);
set local role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.softball_admin_id'), true);
do $$
<<test>>
declare
  game_id uuid;
  state_updated_at timestamptz;
begin
  game_id := public.create_game_with_lineup(
    '00000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-000000000101',
    'Home Run Test',
    '2026-10-03 16:00:00+00',
    array['00000000-0000-4000-8000-000000001001'::uuid]
  );
  select state.updated_at into state_updated_at
  from public.game_states as state where state.game_id = test.game_id;

  perform public.record_plate_appearance(
    game_id,
    'home_run',
    0::smallint,
    1::smallint,
    jsonb_build_array(jsonb_build_object(
      'player_id', '00000000-0000-4000-8000-000000001001',
      'starting_base', 'batter',
      'ending_base', 'home'
    )),
    state_updated_at
  );

  if (select team_score from public.games where id = game_id) <> 1
    or not exists (
      select 1 from public.game_states as state
      where state.game_id = test.game_id
        and inning = 1 and outs = 0 and next_batter_order = 1
        and first_base_player_id is null
        and second_base_player_id is null
        and third_base_player_id is null
    )
  then
    raise exception 'home run did not update run history, score, and state';
  end if;
end;
$$;
rollback;

-- Error, fielder's choice, and a two-out play can end an inning; undo crosses the
-- inning boundary and restores the runner who was on first.
begin;
select set_config(
  'test.softball_admin_id',
  (select user_id::text from public.admin_users order by created_at limit 1),
  true
);
set local role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.softball_admin_id'), true);
do $$
<<test>>
declare
  game_id uuid;
  state_updated_at timestamptz;
begin
  game_id := public.create_game_with_lineup(
    '00000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-000000000101',
    'Multi-out Test',
    '2026-10-04 16:00:00+00',
    array[
      '00000000-0000-4000-8000-000000001001'::uuid,
      '00000000-0000-4000-8000-000000001002'::uuid,
      '00000000-0000-4000-8000-000000001003'::uuid,
      '00000000-0000-4000-8000-000000001004'::uuid
    ]
  );
  select state.updated_at into state_updated_at
  from public.game_states as state where state.game_id = test.game_id;

  perform public.record_plate_appearance(
    game_id, 'reached_on_error', 0::smallint, 0::smallint,
    jsonb_build_array(jsonb_build_object(
      'player_id', '00000000-0000-4000-8000-000000001001',
      'starting_base', 'batter', 'ending_base', 'first'
    )), state_updated_at
  );
  select state.updated_at into state_updated_at
  from public.game_states as state where state.game_id = test.game_id;

  perform public.record_plate_appearance(
    game_id, 'fielders_choice', 1::smallint, 0::smallint,
    jsonb_build_array(
      jsonb_build_object(
        'player_id', '00000000-0000-4000-8000-000000001001',
        'starting_base', 'first', 'ending_base', 'out'
      ),
      jsonb_build_object(
        'player_id', '00000000-0000-4000-8000-000000001002',
        'starting_base', 'batter', 'ending_base', 'first'
      )
    ), state_updated_at
  );
  select state.updated_at into state_updated_at
  from public.game_states as state where state.game_id = test.game_id;

  perform public.record_plate_appearance(
    game_id, 'lineout', 2::smallint, 0::smallint,
    jsonb_build_array(
      jsonb_build_object(
        'player_id', '00000000-0000-4000-8000-000000001002',
        'starting_base', 'first', 'ending_base', 'out'
      ),
      jsonb_build_object(
        'player_id', '00000000-0000-4000-8000-000000001003',
        'starting_base', 'batter', 'ending_base', 'out'
      )
    ), state_updated_at
  );
  select state.updated_at into state_updated_at
  from public.game_states as state where state.game_id = test.game_id;

  if not exists (
    select 1 from public.game_states as state
    where state.game_id = test.game_id and inning = 2 and outs = 0 and next_batter_order = 4
      and first_base_player_id is null and second_base_player_id is null
      and third_base_player_id is null
  ) then
    raise exception 'multi-out play did not end the inning cleanly';
  end if;

  perform public.undo_last_plate_appearance(game_id, state_updated_at);

  if not exists (
    select 1 from public.game_states as state
    where state.game_id = test.game_id and inning = 1 and outs = 1 and next_batter_order = 3
      and first_base_player_id = '00000000-0000-4000-8000-000000001002'
      and second_base_player_id is null and third_base_player_id is null
  ) then
    raise exception 'undo across an inning boundary did not restore the prior state';
  end if;
end;
$$;
rollback;

-- Invalid movements and RBI are rejected without partially changing the event log or state.
begin;
select set_config(
  'test.softball_admin_id',
  (select user_id::text from public.admin_users order by created_at limit 1),
  true
);
set local role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.softball_admin_id'), true);
do $$
<<test>>
declare
  game_id uuid;
  state_updated_at timestamptz;
  rejected_count integer := 0;
begin
  game_id := public.create_game_with_lineup(
    '00000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-000000000101',
    'Invalid Movement Test',
    '2026-10-05 16:00:00+00',
    array[
      '00000000-0000-4000-8000-000000001001'::uuid,
      '00000000-0000-4000-8000-000000001002'::uuid
    ]
  );
  select state.updated_at into state_updated_at
  from public.game_states as state where state.game_id = test.game_id;

  perform public.record_plate_appearance(
    game_id, 'single', 0::smallint, 0::smallint,
    jsonb_build_array(jsonb_build_object(
      'player_id', '00000000-0000-4000-8000-000000001001',
      'starting_base', 'batter', 'ending_base', 'first'
    )), state_updated_at
  );
  select state.updated_at into state_updated_at
  from public.game_states as state where state.game_id = test.game_id;

  begin
    perform public.record_plate_appearance(
      game_id, 'single', 0::smallint, 0::smallint,
      jsonb_build_array(
        jsonb_build_object(
          'player_id', '00000000-0000-4000-8000-000000001001',
          'starting_base', 'first', 'ending_base', 'second'
        ),
        jsonb_build_object(
          'player_id', '00000000-0000-4000-8000-000000001002',
          'starting_base', 'batter', 'ending_base', 'second'
        )
      ), state_updated_at
    );
  exception when invalid_parameter_value then
    rejected_count := rejected_count + 1;
  end;

  begin
    perform public.record_plate_appearance(
      game_id, 'walk', 0::smallint, 0::smallint,
      jsonb_build_array(
        jsonb_build_object(
          'player_id', '00000000-0000-4000-8000-000000001004',
          'starting_base', 'first', 'ending_base', 'second'
        ),
        jsonb_build_object(
          'player_id', '00000000-0000-4000-8000-000000001002',
          'starting_base', 'batter', 'ending_base', 'first'
        )
      ), state_updated_at
    );
  exception when invalid_parameter_value then
    rejected_count := rejected_count + 1;
  end;

  begin
    perform public.record_plate_appearance(
      game_id, 'walk', 0::smallint, 1::smallint,
      jsonb_build_array(
        jsonb_build_object(
          'player_id', '00000000-0000-4000-8000-000000001001',
          'starting_base', 'first', 'ending_base', 'second'
        ),
        jsonb_build_object(
          'player_id', '00000000-0000-4000-8000-000000001002',
          'starting_base', 'batter', 'ending_base', 'first'
        )
      ), state_updated_at
    );
  exception when invalid_parameter_value then
    rejected_count := rejected_count + 1;
  end;

  if rejected_count <> 3
    or (select count(*) from public.plate_appearances as appearance
        where appearance.game_id = test.game_id) <> 1
    or not exists (
      select 1 from public.game_states as state
      where state.game_id = test.game_id and inning = 1 and outs = 0 and next_batter_order = 2
        and first_base_player_id = '00000000-0000-4000-8000-000000001001'
        and second_base_player_id is null and third_base_player_id is null
    )
  then
    raise exception 'invalid play validation was not atomic';
  end if;
end;
$$;
rollback;

-- Authenticated non-admins fail the explicit allowlist check on every mutation.
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '99999999-9999-4999-8999-999999999999', true);
do $$
declare
  rejected_count integer := 0;
begin
  begin
    perform public.record_plate_appearance(
      null::uuid, null::public.plate_appearance_result, null::smallint,
      null::smallint, null::jsonb, null::timestamptz
    );
  exception when insufficient_privilege then
    rejected_count := rejected_count + 1;
  end;

  begin
    perform public.undo_last_plate_appearance(null::uuid, null::timestamptz);
  exception when insufficient_privilege then
    rejected_count := rejected_count + 1;
  end;

  begin
    perform public.finish_game(null::uuid, null::timestamptz);
  exception when insufficient_privilege then
    rejected_count := rejected_count + 1;
  end;

  if rejected_count <> 3 then
    raise exception 'authenticated non-admin scoring unexpectedly succeeded';
  end if;
end;
$$;
rollback;

-- Anonymous callers have no execution privilege on any scoring RPC.
begin;
set local role anon;
do $$
declare
  rejected_count integer := 0;
begin
  begin
    perform public.record_plate_appearance(
      null::uuid, null::public.plate_appearance_result, null::smallint,
      null::smallint, null::jsonb, null::timestamptz
    );
  exception when insufficient_privilege then
    rejected_count := rejected_count + 1;
  end;

  begin
    perform public.undo_last_plate_appearance(null::uuid, null::timestamptz);
  exception when insufficient_privilege then
    rejected_count := rejected_count + 1;
  end;

  begin
    perform public.finish_game(null::uuid, null::timestamptz);
  exception when insufficient_privilege then
    rejected_count := rejected_count + 1;
  end;

  if rejected_count <> 3 then
    raise exception 'anonymous scoring unexpectedly had function execution privilege';
  end if;
end;
$$;
rollback;
