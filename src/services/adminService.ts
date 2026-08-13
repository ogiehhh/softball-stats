import { isSupabaseConfigured, supabase } from '@/lib/supabase'
import type { Database } from '@/types/database.generated'
import type { League, ManagedGameSummary, ManagedSeasonSummary, Season } from '@/types/domain'

export class AdminServiceError extends Error {
  constructor(message: string) {
    super(message)
    this.name = 'AdminServiceError'
  }
}

function assertConfigured(): void {
  if (!isSupabaseConfigured) {
    throw new AdminServiceError('Supabase is not configured for this app.')
  }
}

async function fetchGameCatalog(): Promise<ManagedGameSummary[]> {
  assertConfigured()
  const [gamesResult, seasonsResult, leaguesResult] = await Promise.all([
    supabase.from('games').select('*').order('played_at', { ascending: false }),
    supabase.from('seasons').select('*'),
    supabase.from('leagues').select('*'),
  ])

  if (gamesResult.error || seasonsResult.error || leaguesResult.error) {
    throw new AdminServiceError('Unable to load game management data.')
  }

  const seasons = new Map<string, Season>(seasonsResult.data.map((season) => [season.id, season]))
  const leagues = new Map<string, League>(leaguesResult.data.map((league) => [league.id, league]))

  return gamesResult.data.map((game) => {
    const season = seasons.get(game.season_id)
    const league = season ? leagues.get(season.league_id) : undefined
    if (!season || !league) throw new AdminServiceError('A game is missing its league or season.')
    return { game, season, league }
  })
}

export async function fetchManagedGames(): Promise<ManagedGameSummary[]> {
  const games = await fetchGameCatalog()
  return games.filter(
    (item) => !item.game.archived_at && !item.season.archived_at && !item.league.archived_at,
  )
}

export async function fetchArchivedGames(): Promise<ManagedGameSummary[]> {
  const games = await fetchGameCatalog()
  return games.filter((item) => Boolean(item.game.archived_at))
}

export async function fetchManagedLeagues(): Promise<League[]> {
  assertConfigured()
  const { data, error } = await supabase
    .from('leagues')
    .select('*')
    .is('archived_at', null)
    .order('name')

  if (error) throw new AdminServiceError('Unable to load leagues.')
  return data
}

export async function fetchArchivedLeagues(): Promise<League[]> {
  assertConfigured()
  const { data, error } = await supabase
    .from('leagues')
    .select('*')
    .not('archived_at', 'is', null)
    .order('archived_at', { ascending: false })

  if (error) throw new AdminServiceError('Unable to load archived leagues.')
  return data
}

async function fetchSeasonCatalog(): Promise<ManagedSeasonSummary[]> {
  assertConfigured()
  const [seasonsResult, leaguesResult] = await Promise.all([
    supabase.from('seasons').select('*').order('start_date', { ascending: false }),
    supabase.from('leagues').select('*'),
  ])

  if (seasonsResult.error || leaguesResult.error) {
    throw new AdminServiceError('Unable to load season management data.')
  }

  const leagues = new Map<string, League>(leaguesResult.data.map((league) => [league.id, league]))
  return seasonsResult.data.map((season) => {
    const league = leagues.get(season.league_id)
    if (!league) throw new AdminServiceError('A season is missing its league.')
    return { season, league }
  })
}

export async function fetchManagedSeasons(): Promise<ManagedSeasonSummary[]> {
  const seasons = await fetchSeasonCatalog()
  return seasons.filter((item) => !item.season.archived_at && !item.league.archived_at)
}

export async function fetchArchivedSeasons(): Promise<ManagedSeasonSummary[]> {
  const seasons = await fetchSeasonCatalog()
  return seasons.filter((item) => Boolean(item.season.archived_at))
}

function friendlyActionError(error: { code?: string; message: string }): AdminServiceError {
  if (error.code === '42501' || /authorization|permission|authentication/i.test(error.message)) {
    return new AdminServiceError('Your admin session is not authorized for this action.')
  }
  if (/already archived/i.test(error.message))
    return new AdminServiceError('This item is already deleted.')
  if (/not archived/i.test(error.message))
    return new AdminServiceError('This item is already restored.')
  if (/not found/i.test(error.message))
    return new AdminServiceError('This item could not be found.')
  if (/already on the season roster/i.test(error.message)) {
    return new AdminServiceError('This player is already on the season roster.')
  }
  if (/player with this name already exists/i.test(error.message)) {
    return new AdminServiceError(
      'A player with this name already exists. Choose “Played in another league” instead.',
    )
  }
  if (/recorded game history/i.test(error.message)) {
    return new AdminServiceError(
      'This player has game history in the season and cannot be removed from its roster.',
    )
  }
  if (error.code === '23505' && /season/i.test(error.message)) {
    return new AdminServiceError('A season with this name already exists in that league.')
  }
  if (error.code === '23505' || /already exists/i.test(error.message)) {
    return new AdminServiceError('A league with this name already exists.')
  }
  if (error.code === '22023') return new AdminServiceError(error.message)
  return new AdminServiceError('The change was not saved. Please try again.')
}

export async function createLeague(name: string): Promise<string> {
  assertConfigured()
  const { data, error } = await supabase.rpc('create_league', { p_name: name })
  if (error) throw friendlyActionError(error)
  if (!data) throw new AdminServiceError('The league was not created.')
  return data
}

export async function createSeason(
  leagueId: string,
  name: string,
  startDate: string | null,
  endDate: string | null,
): Promise<string> {
  assertConfigured()
  const parameters: Database['public']['Functions']['create_season']['Args'] = {
    p_league_id: leagueId,
    p_name: name,
  }
  if (startDate) parameters.p_start_date = startDate
  if (endDate) parameters.p_end_date = endDate

  const { data, error } = await supabase.rpc('create_season', parameters)
  if (error) throw friendlyActionError(error)
  if (!data) throw new AdminServiceError('The season was not created.')
  return data
}

export async function createPlayerForSeason(
  seasonId: string,
  displayName: string,
): Promise<string> {
  assertConfigured()
  const { data, error } = await supabase.rpc('create_player_for_season', {
    p_season_id: seasonId,
    p_display_name: displayName,
  })
  if (error) throw friendlyActionError(error)
  if (!data) throw new AdminServiceError('The player was not created.')
  return data
}

export async function addExistingPlayerToSeason(seasonId: string, playerId: string): Promise<void> {
  assertConfigured()
  const { error } = await supabase.rpc('add_existing_player_to_season', {
    p_season_id: seasonId,
    p_player_id: playerId,
  })
  if (error) throw friendlyActionError(error)
}

export async function removePlayerFromSeason(seasonId: string, playerId: string): Promise<void> {
  assertConfigured()
  const { error } = await supabase.rpc('remove_player_from_season', {
    p_season_id: seasonId,
    p_player_id: playerId,
  })
  if (error) throw friendlyActionError(error)
}

export async function completeSeason(seasonId: string): Promise<void> {
  assertConfigured()
  const { error } = await supabase.rpc('complete_season', { p_season_id: seasonId })
  if (error) throw friendlyActionError(error)
}

export async function reopenSeason(seasonId: string): Promise<void> {
  assertConfigured()
  const { error } = await supabase.rpc('reopen_season', { p_season_id: seasonId })
  if (error) throw friendlyActionError(error)
}

export async function archiveSeason(seasonId: string): Promise<void> {
  assertConfigured()
  const { error } = await supabase.rpc('archive_season', { p_season_id: seasonId })
  if (error) throw friendlyActionError(error)
}

export async function restoreSeason(seasonId: string): Promise<void> {
  assertConfigured()
  const { error } = await supabase.rpc('restore_season', { p_season_id: seasonId })
  if (error) throw friendlyActionError(error)
}

export async function archiveGame(gameId: string): Promise<void> {
  assertConfigured()
  const { error } = await supabase.rpc('archive_game', { p_game_id: gameId })
  if (error) throw friendlyActionError(error)
}

export async function restoreGame(gameId: string): Promise<void> {
  assertConfigured()
  const { error } = await supabase.rpc('restore_game', { p_game_id: gameId })
  if (error) throw friendlyActionError(error)
}

export async function archiveLeague(leagueId: string): Promise<void> {
  assertConfigured()
  const { error } = await supabase.rpc('archive_league', { p_league_id: leagueId })
  if (error) throw friendlyActionError(error)
}

export async function restoreLeague(leagueId: string): Promise<void> {
  assertConfigured()
  const { error } = await supabase.rpc('restore_league', { p_league_id: leagueId })
  if (error) throw friendlyActionError(error)
}
