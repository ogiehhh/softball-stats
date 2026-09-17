export type GameStatus = 'draft' | 'in_progress' | 'completed'

export type BaseOrigin = 'batter' | 'first' | 'second' | 'third'
export type BaseDestination = 'first' | 'second' | 'third' | 'home' | 'out'

export type PlateAppearanceResult =
  | 'single'
  | 'double'
  | 'triple'
  | 'home_run'
  | 'walk'
  | 'hit_by_pitch'
  | 'strikeout'
  | 'groundout'
  | 'flyout'
  | 'lineout'
  | 'popout'
  | 'sacrifice_fly'
  | 'fielders_choice'
  | 'reached_on_error'

export interface League {
  id: string
  name: string
  slug: string
  active: boolean
  archived_at: string | null
  archived_by: string | null
  created_at: string
  updated_at: string
}

export interface Season {
  id: string
  league_id: string
  name: string
  start_date: string | null
  end_date: string | null
  active: boolean
  completed_at: string | null
  completed_by: string | null
  archived_at: string | null
  archived_by: string | null
  created_at: string
  updated_at: string
}

export interface Game {
  id: string
  season_id: string
  played_at: string
  opponent: string
  status: GameStatus
  team_score: number | null
  opponent_score: number | null
  archived_at: string | null
  archived_by: string | null
  created_at: string
  updated_at: string
}

export interface Player {
  id: string
  first_name: string
  last_name: string
  display_name: string
  active: boolean
  created_at: string
  updated_at: string
}

export interface GameState {
  game_id: string
  inning: number
  outs: number
  next_batter_order: number
  first_base_player_id: string | null
  second_base_player_id: string | null
  third_base_player_id: string | null
  updated_at: string
}

export interface GameLineupEntry {
  game_id: string
  season_id: string
  player_id: string
  batting_order: number
  player: Player
}

export interface BaseOccupancy {
  first: string | null
  second: string | null
  third: string | null
}

export interface RunnerOutcome {
  playerId: string
  startingBase: BaseOrigin
  endingBase: BaseDestination
}

export interface RecordPlayInput {
  result: Exclude<PlateAppearanceResult, 'hit_by_pitch'>
  rbi: number
  runnerOutcomes: RunnerOutcome[]
}

export interface RecentPlay {
  id: string
  sequenceNo: number
  inning: number
  outsBefore: number
  outsRecorded: number
  result: PlateAppearanceResult
  rbi: number
  batter: Player
  runnerOutcomes: RunnerOutcome[]
}

export interface StartGameInput {
  leagueId: string
  seasonId: string
  opponent: string
  playedAt: string
  lineupPlayerIds: string[]
}

export interface InProgressGameSummary {
  game: Game
  season: Season
  league: League
  state: GameState
}

export interface ManagedGameSummary {
  game: Game
  season: Season
  league: League
}

export interface ManagedSeasonSummary {
  season: Season
  league: League
}

export interface ScoreGameDetails extends InProgressGameSummary {
  lineup: GameLineupEntry[]
  recentPlays: RecentPlay[]
}

export interface BattingCounts {
  games: number
  plate_appearances: number
  at_bats: number
  hits: number
  singles: number
  doubles: number
  triples: number
  home_runs: number
  walks: number
  hit_by_pitch: number
  strikeouts: number
  runs: number
  rbi: number
  sacrifice_flies: number
  fielders_choice: number
  reached_on_error: number
  total_bases: number
}

export interface BattingRates {
  batting_average: number
  on_base_percentage: number
  slugging_percentage: number
  ops: number
}

export interface SeasonBattingStats extends BattingCounts, BattingRates {
  mvp_count: number
  season_id: string
  season_name: string
  league_id: string
  league_name: string
  league_slug: string
  player_id: string
  player_name: string
}
