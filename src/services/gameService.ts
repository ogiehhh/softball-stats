import { isSupabaseConfigured, supabase } from '@/lib/supabase'
import type { Database } from '@/types/database.generated'
import type {
  Game,
  GameLineupEntry,
  GameState,
  InProgressGameSummary,
  League,
  Player,
  RecentPlay,
  RecordPlayInput,
  ScoreGameDetails,
  Season,
  StartGameInput,
} from '@/types/domain'
import { validateLineupPlayerIds } from '@/utils/lineup'
import { countOuts, validateRunnerOutcomes } from '@/utils/scoring'

type PlayerRow = Database['public']['Tables']['players']['Row']
type PlateAppearanceRow = Database['public']['Tables']['plate_appearances']['Row']
type RunnerAdvancementRow = Database['public']['Tables']['runner_advancements']['Row']

export class GameServiceError extends Error {
  constructor(message: string) {
    super(message)
    this.name = 'GameServiceError'
  }
}

function assertConfigured(): void {
  if (!isSupabaseConfigured) {
    throw new GameServiceError(
      'Supabase is not configured. Add the public project values to .env.local.',
    )
  }
}

function mapPlayer(row: PlayerRow): Player {
  return {
    ...row,
    display_name: row.display_name ?? `${row.first_name} ${row.last_name}`.trim(),
  }
}

function friendlyGameError(error: { code?: string; message: string }): GameServiceError {
  if (error.code === '42501' || /authorization|permission|authentication/i.test(error.message)) {
    return new GameServiceError('Your admin session is not authorized to perform this action.')
  }

  if (/roster/i.test(error.message)) {
    return new GameServiceError(
      'The season roster changed. Refresh the roster and rebuild the lineup before trying again.',
    )
  }

  if (/duplicate|only once/i.test(error.message)) {
    return new GameServiceError('A player can appear only once in the lineup.')
  }

  if (/lineup.*at least one|lineup must contain/i.test(error.message)) {
    return new GameServiceError('Add at least one rostered player before starting the game.')
  }

  if (/season/i.test(error.message)) {
    return new GameServiceError('The selected league or season is no longer available.')
  }

  return new GameServiceError('The game could not be started. Nothing was saved; please try again.')
}

function friendlyScoringError(error: { code?: string; message: string }): GameServiceError {
  if (error.code === '40001' || /game state changed/i.test(error.message)) {
    return new GameServiceError('This game changed in another tab. Reloaded the latest state.')
  }

  if (error.code === '42501' || /authorization|permission|authentication/i.test(error.message)) {
    return new GameServiceError('Your admin session is not authorized to score this game.')
  }

  if (/no plate appearance/i.test(error.message)) {
    return new GameServiceError('There is no play to undo.')
  }

  if (/in-progress game|in progress game|in-progress/i.test(error.message)) {
    return new GameServiceError('This game is no longer in progress.')
  }

  if (/archived/i.test(error.message)) {
    return new GameServiceError('This game is archived. Restore it before scoring.')
  }

  if (error.code === '22023') return new GameServiceError(error.message)
  return new GameServiceError('The scoring change was not saved. Refresh and try again.')
}

export async function fetchSeasonRoster(seasonId: string): Promise<Player[]> {
  assertConfigured()
  const { data, error } = await supabase
    .from('season_players')
    .select('player:players(*)')
    .eq('season_id', seasonId)

  if (error) throw new GameServiceError('Unable to load this season roster.')

  return data
    .map((row) => row.player)
    .filter((row): row is PlayerRow => Boolean(row?.active))
    .map(mapPlayer)
    .sort((left, right) => left.display_name.localeCompare(right.display_name))
}

export async function startGame(input: StartGameInput, roster: Player[]): Promise<string> {
  assertConfigured()

  const validation = validateLineupPlayerIds(
    input.lineupPlayerIds,
    roster.map((player) => player.id),
  )
  if (!validation.valid) throw new GameServiceError(validation.message)
  if (!input.leagueId || !input.seasonId) {
    throw new GameServiceError('Choose a league and season before starting the game.')
  }
  if (!input.opponent.trim()) throw new GameServiceError('Enter an opponent name.')
  if (!input.playedAt) throw new GameServiceError('Choose a game date.')

  const { data, error } = await supabase.rpc('create_game_with_lineup', {
    p_league_id: input.leagueId,
    p_season_id: input.seasonId,
    p_opponent: input.opponent.trim(),
    p_played_at: input.playedAt,
    p_lineup_player_ids: input.lineupPlayerIds,
  })

  if (error) throw friendlyGameError(error)
  if (!data) throw new GameServiceError('The game was not created. Nothing was saved.')
  return data
}

async function fetchLeagueAndSeason(seasonId: string): Promise<{ season: Season; league: League }> {
  const { data, error } = await supabase
    .from('seasons')
    .select('*, league:leagues(*)')
    .eq('id', seasonId)
    .single()

  if (error || !data.league) throw new GameServiceError('The game season could not be loaded.')
  if (data.league.archived_at) {
    throw new GameServiceError('This game belongs to an archived league.')
  }
  return { season: data, league: data.league }
}

export async function fetchInProgressGames(): Promise<InProgressGameSummary[]> {
  assertConfigured()

  const { data: games, error } = await supabase
    .from('games')
    .select('*')
    .eq('status', 'in_progress')
    .is('archived_at', null)
    .order('played_at', { ascending: false })

  if (error) throw new GameServiceError('Unable to load in-progress games.')

  const visibleGames = await Promise.all(
    games.map(async (game) => {
      try {
        const [{ season, league }, state] = await Promise.all([
          fetchLeagueAndSeason(game.season_id),
          fetchGameState(game.id),
        ])
        return { game, season, league, state }
      } catch (loadError) {
        if (
          loadError instanceof GameServiceError &&
          /archived league|season could not be loaded/i.test(loadError.message)
        ) {
          return null
        }
        throw loadError
      }
    }),
  )

  return visibleGames.filter((game): game is InProgressGameSummary => game !== null)
}

export async function fetchGameState(gameId: string): Promise<GameState> {
  assertConfigured()
  const { data, error } = await supabase
    .from('game_states')
    .select('*')
    .eq('game_id', gameId)
    .single()

  if (error) throw new GameServiceError('This game has no persisted state to resume.')
  return data
}

export async function fetchGameLineup(gameId: string): Promise<GameLineupEntry[]> {
  assertConfigured()
  const { data, error } = await supabase
    .from('game_lineup')
    .select('game_id, season_id, player_id, batting_order, player:players(*)')
    .eq('game_id', gameId)
    .order('batting_order')

  if (error) throw new GameServiceError('The batting lineup could not be loaded.')

  return data.map((row) => {
    if (!row.player) throw new GameServiceError('A lineup player could not be loaded.')
    return { ...row, player: mapPlayer(row.player) }
  })
}

async function fetchRecentPlays(gameId: string, lineup: GameLineupEntry[]): Promise<RecentPlay[]> {
  const { data: appearances, error: appearanceError } = await supabase
    .from('plate_appearances')
    .select('*')
    .eq('game_id', gameId)
    .order('sequence_no', { ascending: false })
    .limit(5)

  if (appearanceError) throw new GameServiceError('Recent plays could not be loaded.')
  if (!appearances.length) return []

  const { data: advancements, error: advancementError } = await supabase
    .from('runner_advancements')
    .select('*')
    .in(
      'plate_appearance_id',
      appearances.map((appearance) => appearance.id),
    )

  if (advancementError) throw new GameServiceError('Recent runner movement could not be loaded.')

  const lineupPlayers = new Map(lineup.map((entry) => [entry.player_id, entry.player]))
  const originOrder = { third: 0, second: 1, first: 2, batter: 3 }

  return (appearances as PlateAppearanceRow[]).map((appearance) => {
    const batter = lineupPlayers.get(appearance.player_id)
    if (!batter) throw new GameServiceError('A recent play references a player outside the lineup.')

    return {
      id: appearance.id,
      sequenceNo: appearance.sequence_no,
      inning: appearance.inning,
      outsBefore: appearance.outs_before,
      outsRecorded: appearance.outs_recorded,
      result: appearance.result,
      rbi: appearance.rbi,
      batter,
      runnerOutcomes: (advancements as RunnerAdvancementRow[])
        .filter((advancement) => advancement.plate_appearance_id === appearance.id)
        .sort((left, right) => originOrder[left.starting_base] - originOrder[right.starting_base])
        .map((advancement) => ({
          playerId: advancement.player_id,
          startingBase: advancement.starting_base,
          endingBase: advancement.ending_base,
        })),
    }
  })
}

export async function fetchScoreGameDetails(gameId: string): Promise<ScoreGameDetails> {
  assertConfigured()
  const { data: game, error } = await supabase
    .from('games')
    .select('*')
    .eq('id', gameId)
    .is('archived_at', null)
    .single()

  if (error) throw new GameServiceError('Game not found.')

  const [{ season, league }, state, lineup] = await Promise.all([
    fetchLeagueAndSeason(game.season_id),
    fetchGameState(game.id),
    fetchGameLineup(game.id),
  ])

  if (!lineup.length) throw new GameServiceError('This game has no batting lineup.')
  if (!lineup.some((entry) => entry.batting_order === state.next_batter_order)) {
    throw new GameServiceError('The current batting-order position is outside this lineup.')
  }

  const recentPlays = await fetchRecentPlays(game.id, lineup)
  return { game: game as Game, season, league, state, lineup, recentPlays }
}

export async function recordPlateAppearance(
  gameId: string,
  state: GameState,
  input: RecordPlayInput,
): Promise<string> {
  assertConfigured()
  const validationMessage = validateRunnerOutcomes(input.runnerOutcomes, state.outs, input.rbi)
  if (validationMessage) throw new GameServiceError(validationMessage)

  const { data, error } = await supabase.rpc('record_plate_appearance', {
    p_game_id: gameId,
    p_result: input.result,
    p_outs_recorded: countOuts(input.runnerOutcomes),
    p_rbi: input.rbi,
    p_runner_outcomes: input.runnerOutcomes.map((outcome) => ({
      player_id: outcome.playerId,
      starting_base: outcome.startingBase,
      ending_base: outcome.endingBase,
    })),
    p_expected_state_updated_at: state.updated_at,
  })

  if (error) throw friendlyScoringError(error)
  if (!data) throw new GameServiceError('The play was not saved. Refresh and try again.')
  return data
}

export async function undoLastPlateAppearance(
  gameId: string,
  expectedStateUpdatedAt: string,
): Promise<string> {
  assertConfigured()
  const { data, error } = await supabase.rpc('undo_last_plate_appearance', {
    p_game_id: gameId,
    p_expected_state_updated_at: expectedStateUpdatedAt,
  })

  if (error) throw friendlyScoringError(error)
  if (!data) throw new GameServiceError('The latest play was not undone.')
  return data
}

export async function finishGame(gameId: string, expectedStateUpdatedAt: string): Promise<string> {
  assertConfigured()
  const { data, error } = await supabase.rpc('finish_game', {
    p_game_id: gameId,
    p_expected_state_updated_at: expectedStateUpdatedAt,
  })

  if (error) throw friendlyScoringError(error)
  if (!data) throw new GameServiceError('The game was not finished.')
  return data
}
