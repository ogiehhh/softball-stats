-- Allow an enrolled admin to correct the start and end dates of a visible
-- season without exposing direct table writes as the UI boundary.

create function public.update_season_dates(
  p_season_id uuid,
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
  target public.seasons%rowtype;
begin
  if caller_id is null or not exists (
    select 1 from public.admin_users where user_id = caller_id
  ) then
    raise insufficient_privilege using message = 'Admin authorization is required.';
  end if;

  if p_start_date is not null and p_end_date is not null and p_end_date < p_start_date then
    raise invalid_parameter_value using message = 'The season end date cannot be before its start date.';
  end if;

  select * into target
  from public.seasons
  where id = p_season_id
  for update;

  if not found then
    raise invalid_parameter_value using message = 'Season not found.';
  end if;
  if target.archived_at is not null then
    raise invalid_parameter_value using message = 'Restore the season before editing its dates.';
  end if;
  if not exists (
    select 1 from public.leagues
    where id = target.league_id and archived_at is null
  ) then
    raise invalid_parameter_value using message = 'Restore the league before editing season dates.';
  end if;

  update public.seasons
  set start_date = p_start_date,
      end_date = p_end_date
  where id = p_season_id;

  return p_season_id;
end;
$$;

revoke execute on function public.update_season_dates(uuid, date, date) from public, anon;
grant execute on function public.update_season_dates(uuid, date, date) to authenticated;

comment on function public.update_season_dates(uuid, date, date) is
  'Admin-only correction of a visible season start and end date.';
