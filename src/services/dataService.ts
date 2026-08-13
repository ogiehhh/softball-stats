import { isSupabaseConfigured, supabase } from '@/lib/supabase'
import type { Database } from '@/types/database.generated'
import type { Game, League, Player, Season, SeasonBattingStats } from '@/types/domain'
import { aggregateSeasonStats } from '@/utils/statistics'

type SeasonStatsRow = Database['public']['Views']['season_batting_stats']['Row']

export class DataServiceError extends Error {
  constructor(message: string) {
    super(message)
    this.name = 'DataServiceError'
  }
}

function configurationMessage(): string {
  return 'Supabase is not configured. Copy .env.example to .env.local and add the project URL and publishable key.'
}

function assertConfigured(): void {
  if (!isSupabaseConfigured) throw new DataServiceError(configurationMessage())
}

function throwQueryError(message: string, error: { message: string }): never {
  throw new DataServiceError(`${message}: ${error.message}`)
}

function mapSeasonStats(row: SeasonStatsRow): SeasonBattingStats {
  return {
    season_id: row.season_id ?? '',
    season_name: row.season_name ?? '',
    league_id: row.league_id ?? '',
    league_name: row.league_name ?? '',
    league_slug: row.league_slug ?? '',
    player_id: row.player_id ?? '',
    player_name: row.player_name ?? '',
    games: row.games ?? 0,
    plate_appearances: row.plate_appearances ?? 0,
    at_bats: row.at_bats ?? 0,
    hits: row.hits ?? 0,
    singles: row.singles ?? 0,
    doubles: row.doubles ?? 0,
    triples: row.triples ?? 0,
    home_runs: row.home_runs ?? 0,
    walks: row.walks ?? 0,
    hit_by_pitch: row.hit_by_pitch ?? 0,
    strikeouts: row.strikeouts ?? 0,
    runs: row.runs ?? 0,
    rbi: row.rbi ?? 0,
    sacrifice_flies: row.sacrifice_flies ?? 0,
    fielders_choice: row.fielders_choice ?? 0,
    reached_on_error: row.reached_on_error ?? 0,
    total_bases: row.total_bases ?? 0,
    batting_average: Number(row.batting_average ?? 0),
    on_base_percentage: Number(row.on_base_percentage ?? 0),
    slugging_percentage: Number(row.slugging_percentage ?? 0),
    ops: Number(row.ops ?? 0),
  }
}

function mapPlayer(row: Database['public']['Tables']['players']['Row']): Player {
  return {
    ...row,
    display_name: row.display_name ?? `${row.first_name} ${row.last_name}`.trim(),
  }
}

export async function fetchLeagues(): Promise<League[]> {
  assertConfigured()
  const { data, error } = await supabase
    .from('leagues')
    .select('*')
    .eq('active', true)
    .is('archived_at', null)
    .order('name')

  if (error) throwQueryError('Unable to load leagues', error)
  return data
}

export async function fetchLeagueBySlug(slug: string): Promise<League> {
  assertConfigured()
  const { data, error } = await supabase
    .from('leagues')
    .select('*')
    .eq('slug', slug)
    .is('archived_at', null)
    .single()

  if (error) throwQueryError('Unable to load league', error)
  return data
}

export async function fetchLeague(leagueId: string): Promise<League> {
  assertConfigured()
  const { data, error } = await supabase
    .from('leagues')
    .select('*')
    .eq('id', leagueId)
    .is('archived_at', null)
    .single()

  if (error) throwQueryError('Unable to load league', error)
  return data
}

export async function fetchSeasonsForLeague(leagueId: string): Promise<Season[]> {
  assertConfigured()
  await fetchLeague(leagueId)
  const { data, error } = await supabase
    .from('seasons')
    .select('*')
    .eq('league_id', leagueId)
    .is('archived_at', null)
    .order('start_date', { ascending: false, nullsFirst: false })

  if (error) throwQueryError('Unable to load seasons', error)
  return data
}

export async function fetchActiveSeasonsForLeague(leagueId: string): Promise<Season[]> {
  const seasons = await fetchSeasonsForLeague(leagueId)
  return seasons.filter((season) => season.active)
}

export async function fetchSeason(seasonId: string): Promise<Season> {
  assertConfigured()
  const { data, error } = await supabase
    .from('seasons')
    .select('*')
    .eq('id', seasonId)
    .is('archived_at', null)
    .single()

  if (error) throwQueryError('Unable to load season', error)
  await fetchLeague(data.league_id)
  return data
}

export async function fetchGamesForSeason(seasonId: string): Promise<Game[]> {
  assertConfigured()
  const { data, error } = await supabase
    .from('games')
    .select('*')
    .eq('season_id', seasonId)
    .is('archived_at', null)
    .order('played_at', { ascending: false })

  if (error) throwQueryError('Unable to load games', error)
  return data
}

export async function fetchSeasonStatistics(seasonId: string): Promise<SeasonBattingStats[]> {
  assertConfigured()
  const { data, error } = await supabase
    .from('season_batting_stats')
    .select('*')
    .eq('season_id', seasonId)
    .order('player_name')

  if (error) throwQueryError('Unable to load batting statistics', error)
  return data.map(mapSeasonStats)
}

export async function fetchLeagueStatistics(leagueId: string): Promise<SeasonBattingStats[]> {
  assertConfigured()
  const { data, error } = await supabase
    .from('season_batting_stats')
    .select('*')
    .eq('league_id', leagueId)
    .order('player_name')

  if (error) throwQueryError('Unable to load league statistics', error)

  const playerLines = new Map<string, SeasonBattingStats[]>()
  for (const row of data.map(mapSeasonStats)) {
    const lines = playerLines.get(row.player_id) ?? []
    lines.push(row)
    playerLines.set(row.player_id, lines)
  }

  return Array.from(playerLines.values())
    .map((lines) => {
      const first = lines[0]
      if (!first) throw new DataServiceError('A league statistic is missing its player.')
      return {
        ...first,
        season_id: 'all-time:' + leagueId,
        season_name: 'All time',
        ...aggregateSeasonStats(lines),
      }
    })
    .sort((left, right) => left.player_name.localeCompare(right.player_name))
}

export async function fetchPlayers(): Promise<Player[]> {
  assertConfigured()
  const { data, error } = await supabase
    .from('players')
    .select('*')
    .eq('active', true)
    .order('last_name')
    .order('first_name')

  if (error) throwQueryError('Unable to load players', error)
  return data.map(mapPlayer)
}

export async function fetchPlayer(playerId: string): Promise<Player> {
  assertConfigured()
  const { data, error } = await supabase.from('players').select('*').eq('id', playerId).single()

  if (error) throwQueryError('Unable to load player', error)
  return mapPlayer(data)
}

export async function fetchPlayerSeasonStatistics(playerId: string): Promise<SeasonBattingStats[]> {
  assertConfigured()
  const { data, error } = await supabase
    .from('season_batting_stats')
    .select('*')
    .eq('player_id', playerId)
    .order('season_name', { ascending: false })

  if (error) throwQueryError('Unable to load player statistics', error)
  return data.map(mapSeasonStats)
}

export async function fetchAllSeasonStatistics(): Promise<SeasonBattingStats[]> {
  assertConfigured()
  const { data, error } = await supabase
    .from('season_batting_stats')
    .select('*')
    .order('season_name', { ascending: false })
    .order('player_name')

  if (error) throwQueryError('Unable to load all-time statistics', error)
  return data.map(mapSeasonStats)
}
