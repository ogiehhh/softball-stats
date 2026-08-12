-- Remove only the two fixed sample games shipped with the original seed.
-- Child game state, lineup, plate appearance, and advancement rows cascade.
delete from public.games
where id in (
  '00000000-0000-4000-8000-000000002001',
  '00000000-0000-4000-8000-000000002002'
);
