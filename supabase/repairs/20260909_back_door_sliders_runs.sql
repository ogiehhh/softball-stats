-- Authorized correction: September 9, 2026 vs Back Door Sliders, 11 runs -> 9.
-- Run as the database owner. Identifies the game without environment-specific UUIDs.
-- Only plays 4 and 32 are corrected; event history, outs and hits remain intact.
begin;
do $$
declare
  target_game uuid;
  target_count integer;
  recorded_score integer;
  affected_count integer;
begin
  select count(*), (array_agg(id))[1] into target_count, target_game
  from public.games
  where opponent = 'Back Door Sliders'
    and (played_at at time zone 'America/New_York')::date = date '2026-09-09'
    and archived_at is null;
  if target_count <> 1 then
    raise exception 'Expected exactly one September 9 Back Door Sliders game, found %', target_count;
  end if;

  select team_score into recorded_score from public.games
  where id = target_game and status = 'completed' for update;
  perform 1 from public.game_states where game_id = target_game for update;
  if recorded_score is null or recorded_score not in (9, 11) then
    raise exception 'Expected completed game with 11 runs (or already corrected to 9)';
  end if;

  select count(*) into affected_count from public.plate_appearances
  where game_id = target_game and sequence_no in (4, 32)
    and inning = case sequence_no when 4 then 1 else 5 end
    and result = 'groundout' and outs_before = 2 and outs_recorded = 1
    and rbi = case recorded_score when 11 then 1 else 0 end;
  if affected_count <> 2 then raise exception 'The two reviewed third-out plays changed'; end if;

  if (select count(*) from public.runner_advancements ra
      join public.plate_appearances pa on pa.id = ra.plate_appearance_id
      where pa.game_id = target_game and ra.ending_base = 'home') <> recorded_score then
    raise exception 'Score and recorded run events disagree';
  end if;

  if recorded_score = 11 then
    select count(*) into affected_count from public.runner_advancements ra
    join public.plate_appearances pa on pa.id = ra.plate_appearance_id
    where pa.game_id = target_game and pa.sequence_no in (4, 32)
      and ra.starting_base = 'third' and ra.ending_base = 'home';
    if affected_count <> 2 then raise exception 'Expected two erroneous runs from third base'; end if;

    update public.runner_advancements ra
    set ending_base = ra.starting_base::text::public.base_destination
    from public.plate_appearances pa
    where pa.id = ra.plate_appearance_id and pa.game_id = target_game
      and pa.sequence_no in (4, 32)
      and ra.starting_base <> 'batter' and ra.ending_base <> 'out';

    update public.plate_appearances set rbi = 0
    where game_id = target_game and sequence_no in (4, 32);

    update public.games set team_score = (
      select count(*) from public.runner_advancements ra
      join public.plate_appearances pa on pa.id = ra.plate_appearance_id
      where pa.game_id = target_game and ra.ending_base = 'home'
    ) where id = target_game;
  end if;

  if (select team_score from public.games where id = target_game) <> 9
    or (select sum(rbi) from public.plate_appearances where game_id = target_game) <> 9
    or exists (
      select 1 from public.runner_advancements ra
      join public.plate_appearances pa on pa.id = ra.plate_appearance_id
      where pa.game_id = target_game and pa.sequence_no in (4, 32)
        and ra.ending_base = 'home'
    ) then raise exception 'Corrected game must have exactly 9 runs and 9 RBI'; end if;
end;
$$;
commit;
