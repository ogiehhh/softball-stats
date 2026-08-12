-- Connected-development validation for create_game_with_lineup.
-- Requires the deterministic seed and one enrolled admin user. Every write is rolled back.

do $$
begin
  if not exists (select 1 from public.admin_users) then
    raise exception 'game initialization tests require one public.admin_users row';
  end if;
end;
$$;

-- An authorized admin can atomically create the expected initial state.
begin;
select set_config(
  'test.softball_admin_id',
  (select user_id::text from public.admin_users order by created_at limit 1),
  true
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  current_setting('test.softball_admin_id'),
  true
);

do $$
declare
  created_game_id uuid;
  created_game public.games%rowtype;
  created_state public.game_states%rowtype;
begin
  created_game_id := public.create_game_with_lineup(
    '00000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-000000000101',
    'RPC Test Opponent',
    '2026-10-01 16:00:00+00',
    array[
      '00000000-0000-4000-8000-000000001003'::uuid,
      '00000000-0000-4000-8000-000000001001'::uuid
    ]
  );

  select * into strict created_game
  from public.games where id = created_game_id;

  select * into strict created_state
  from public.game_states where game_id = created_game_id;

  if created_game.status <> 'in_progress'
    or created_game.opponent <> 'RPC Test Opponent'
    or created_game.team_score <> 0
    or created_state.inning <> 1
    or created_state.outs <> 0
    or created_state.next_batter_order <> 1
    or created_state.first_base_player_id is not null
    or created_state.second_base_player_id is not null
    or created_state.third_base_player_id is not null
    or (select count(*) from public.game_lineup where game_id = created_game_id) <> 2
    or (select player_id from public.game_lineup where game_id = created_game_id and batting_order = 1)
      <> '00000000-0000-4000-8000-000000001003'::uuid
  then
    raise exception 'valid initialization did not create the expected game, lineup, and state';
  end if;
end;
$$;
rollback;

-- An authenticated non-admin cannot start a game.
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '99999999-9999-4999-8999-999999999999', true);
do $$
declare
  rejected boolean := false;
begin
  begin
    perform public.create_game_with_lineup(
      '00000000-0000-4000-8000-000000000001',
      '00000000-0000-4000-8000-000000000101',
      'Unauthorized Test',
      '2026-10-01 16:00:00+00',
      array['00000000-0000-4000-8000-000000001001'::uuid]
    );
  exception when insufficient_privilege then
    rejected := true;
  end;

  if not rejected then
    raise exception 'authenticated non-admin initialization unexpectedly succeeded';
  end if;
end;
$$;
rollback;

-- Duplicate and non-rostered lineups fail before creating any partial records.
begin;
select set_config(
  'test.softball_admin_id',
  (select user_id::text from public.admin_users order by created_at limit 1),
  true
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  current_setting('test.softball_admin_id'),
  true
);
do $$
declare
  games_before bigint;
  lineups_before bigint;
  states_before bigint;
  rejected_count integer := 0;
begin
  select count(*) into games_before from public.games;
  select count(*) into lineups_before from public.game_lineup;
  select count(*) into states_before from public.game_states;

  begin
    perform public.create_game_with_lineup(
      '00000000-0000-4000-8000-000000000001',
      '00000000-0000-4000-8000-000000000101',
      'Duplicate Test',
      '2026-10-01 16:00:00+00',
      array[
        '00000000-0000-4000-8000-000000001001'::uuid,
        '00000000-0000-4000-8000-000000001001'::uuid
      ]
    );
  exception when invalid_parameter_value then
    rejected_count := rejected_count + 1;
  end;

  begin
    perform public.create_game_with_lineup(
      '00000000-0000-4000-8000-000000000001',
      '00000000-0000-4000-8000-000000000101',
      'Roster Test',
      '2026-10-01 16:00:00+00',
      array['99999999-9999-4999-8999-999999999999'::uuid]
    );
  exception when invalid_parameter_value then
    rejected_count := rejected_count + 1;
  end;

  begin
    perform public.create_game_with_lineup(
      '00000000-0000-4000-8000-000000000001',
      '00000000-0000-4000-8000-000000000101',
      'Empty Test',
      '2026-10-01 16:00:00+00',
      array[]::uuid[]
    );
  exception when invalid_parameter_value then
    rejected_count := rejected_count + 1;
  end;

  if rejected_count <> 3
    or (select count(*) from public.games) <> games_before
    or (select count(*) from public.game_lineup) <> lineups_before
    or (select count(*) from public.game_states) <> states_before
  then
    raise exception 'invalid initialization was not rejected atomically';
  end if;
end;
$$;
rollback;

-- Anonymous callers do not have function execution privilege.
begin;
set local role anon;
do $$
declare
  rejected boolean := false;
begin
  begin
    perform public.create_game_with_lineup(
      '00000000-0000-4000-8000-000000000001',
      '00000000-0000-4000-8000-000000000101',
      'Anonymous Test',
      '2026-10-01 16:00:00+00',
      array['00000000-0000-4000-8000-000000001001'::uuid]
    );
  exception when insufficient_privilege then
    rejected := true;
  end;

  if not rejected then
    raise exception 'anonymous initialization unexpectedly succeeded';
  end if;
end;
$$;
rollback;
