-- Admin-only league creation. The database owns normalization and slug generation
-- so every client gets the same validation and URL-safe identifier.
create function public.create_league(p_name text)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  normalized_name text := btrim(regexp_replace(coalesce(p_name, ''), '\s+', ' ', 'g'));
  slug_base text;
  candidate_slug text;
  slug_suffix integer := 1;
  created_league_id uuid;
begin
  if caller_id is null or not exists (
    select 1
    from public.admin_users
    where user_id = caller_id
  ) then
    raise exception using
      errcode = '42501',
      message = 'Admin authorization is required to create a league.';
  end if;

  if normalized_name = '' then
    raise exception using
      errcode = '22023',
      message = 'A league name is required.';
  end if;

  if char_length(normalized_name) > 100 then
    raise exception using
      errcode = '22023',
      message = 'League names must be 100 characters or fewer.';
  end if;

  if exists (
    select 1
    from public.leagues
    where lower(name) = lower(normalized_name)
  ) then
    raise exception using
      errcode = '23505',
      message = 'A league with this name already exists.';
  end if;

  slug_base := trim(
    both '-'
    from regexp_replace(lower(normalized_name), '[^a-z0-9]+', '-', 'g')
  );

  if slug_base = '' then
    raise exception using
      errcode = '22023',
      message = 'The league name must include at least one letter or number.';
  end if;

  candidate_slug := slug_base;
  while exists (select 1 from public.leagues where slug = candidate_slug) loop
    slug_suffix := slug_suffix + 1;
    candidate_slug := slug_base || '-' || slug_suffix::text;
  end loop;

  insert into public.leagues (name, slug)
  values (normalized_name, candidate_slug)
  returning id into created_league_id;

  return created_league_id;
end;
$$;

comment on function public.create_league(text) is
  'Creates an active league with a generated unique slug after explicit admin authorization.';

revoke execute on function public.create_league(text) from public, anon;
grant execute on function public.create_league(text) to authenticated;
