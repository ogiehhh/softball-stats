
-- Cover composite foreign keys used during parent updates/deletes and scoring lookups.
create index game_lineup_game_season_idx
  on public.game_lineup(game_id, season_id);

create index game_lineup_season_player_idx
  on public.game_lineup(season_id, player_id);

create index game_states_first_base_idx
  on public.game_states(game_id, first_base_player_id);

create index game_states_second_base_idx
  on public.game_states(game_id, second_base_player_id);

create index game_states_third_base_idx
  on public.game_states(game_id, third_base_player_id);

create index plate_appearances_game_player_idx
  on public.plate_appearances(game_id, player_id);
