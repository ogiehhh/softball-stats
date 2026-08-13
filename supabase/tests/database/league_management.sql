-- Connected rollback-only validation for admin league creation and archive visibility.
begin;

do $$
begin
  if not exists (select 1 from public.admin_users) then
    raise exception 'league management tests require one public.admin_users row';
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
  '40000000-0000-4000-8000-000000000001',
  'League Slug Fixture',
  'league-management-test'
);

do $$
declare
  created_id uuid;
  duplicate_rejected boolean := false;
begin
  created_id := public.create_league('  League   Management   Test  ');
  perform set_config('test.created_league_id', created_id::text, true);

  if not exists (
    select 1
    from public.leagues
    where id = created_id
      and name = 'League Management Test'
      and slug = 'league-management-test-2'
      and active
      and archived_at is null
      and archived_by is null
  ) then
    raise exception 'admin league creation did not normalize and persist the expected row';
  end if;

  begin
    perform public.create_league('league management test');
  exception when unique_violation then
    duplicate_rejected := true;
  end;

  if not duplicate_rejected then
    raise exception 'duplicate league name was accepted';
  end if;

  perform public.archive_league(created_id);

  if exists (
    select 1
    from public.leagues
    where id = created_id
      and active
      and archived_at is null
  ) then
    raise exception 'archived league remains in the scorer league query';
  end if;
end;
$$;

-- Anonymous callers cannot see the archive or execute creation.
set local role anon;
select set_config('request.jwt.claim.sub', '', true);
do $$
declare
  create_rejected boolean := false;
begin
  if exists (
    select 1 from public.leagues
    where id = current_setting('test.created_league_id')::uuid
  ) then
    raise exception 'anonymous read exposed an archived league';
  end if;

  begin
    perform public.create_league('Anonymous League');
  exception when insufficient_privilege then
    create_rejected := true;
  end;

  if not create_rejected then
    raise exception 'anonymous league creation unexpectedly succeeded';
  end if;
end;
$$;

-- Authentication without enrollment in admin_users is still rejected.
set local role authenticated;
select set_config('request.jwt.claim.sub', '99999999-9999-4999-8999-999999999999', true);
do $$
declare
  create_rejected boolean := false;
begin
  begin
    perform public.create_league('Non-admin League');
  exception when insufficient_privilege then
    create_rejected := true;
  end;

  if not create_rejected then
    raise exception 'authenticated non-admin league creation unexpectedly succeeded';
  end if;
end;
$$;

-- The enrolled admin can restore the same intact league.
select set_config('request.jwt.claim.sub', current_setting('test.softball_admin_id'), true);
do $$
begin
  perform public.restore_league(current_setting('test.created_league_id')::uuid);

  if not exists (
    select 1
    from public.leagues
    where id = current_setting('test.created_league_id')::uuid
      and archived_at is null
      and archived_by is null
  ) then
    raise exception 'admin league restore did not clear archive metadata';
  end if;
end;
$$;

rollback;
