import { isSupabaseConfigured, supabase } from '@/lib/supabase'
import type { Database } from '@/types/database.generated'
import type { Game, League, Player, Season, SeasonBattingStats } from '@/types/domain'
import { aggregateSeasonStats } from '@/utils/statistics'
import { gameHighlights, type GameHighlight, type HighlightPlay } from '@/utils/gameHighlights'

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
    mvp_count: 0,
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

async function fetchHighlightGames(filter: { gameId: string } | { seasonIds: string[] }) {
  assertConfigured()
  const games = new Map<string, { seasonId: string; plays: HighlightPlay[] }>()
  const pageSize = 500
  for (let offset = 0; ; offset += pageSize) {
    let query = supabase
      .from('plate_appearances')
      .select(
        `game_id, player_id, result, rbi,
        games!inner(season_id, status, archived_at, seasons!inner(archived_at, leagues!inner(archived_at))),
        players!plate_appearances_player_id_fkey(first_name, last_name, display_name),
        runner_advancements(player_id, ending_base, players!runner_advancements_player_id_fkey(first_name, last_name, display_name))`,
      )
      .eq('games.status', 'completed')
      .is('games.archived_at', null)
      .is('games.seasons.archived_at', null)
      .is('games.seasons.leagues.archived_at', null)
      .order('game_id')
      .order('sequence_no')
      .range(offset, offset + pageSize - 1)
    query =
      'gameId' in filter
        ? query.eq('game_id', filter.gameId)
        : query.in('games.season_id', filter.seasonIds)
    const { data, error } = await query
    if (error) throwQueryError('Unable to load game highlights', error)
    const name = (
      person: { display_name: string | null; first_name: string; last_name: string } | null,
    ) =>
      person
        ? (person.display_name ?? `${person.first_name} ${person.last_name}`.trim())
        : 'Unknown player'
    for (const play of data) {
      let game = games.get(play.game_id)
      if (!game) {
        game = { seasonId: play.games.season_id, plays: [] }
        games.set(play.game_id, game)
      }
      game.plays.push({
        player_id: play.player_id,
        player_name: name(play.players),
        result: play.result,
        rbi: play.rbi,
        scorers: play.runner_advancements
          .filter((runner) => runner.ending_base === 'home')
          .map((runner) => ({ player_id: runner.player_id, player_name: name(runner.players) })),
      })
    }
    if (data.length < pageSize) break
  }
  return games
}

export async function fetchGameHighlights(gameId: string): Promise<GameHighlight[]> {
  const games = await fetchHighlightGames({ gameId })
  return gameHighlights(games.get(gameId)?.plays ?? [])
}

async function withMvpCounts(rows: SeasonBattingStats[]): Promise<SeasonBattingStats[]> {
  const seasonIds = [...new Set(rows.map((row) => row.season_id))]
  const counts = new Map<string, number>()
  // Batch seasons and paginate plays; never truncate an award at the API row limit.
  for (let start = 0; start < seasonIds.length; start += 50) {
    const games = await fetchHighlightGames({ seasonIds: seasonIds.slice(start, start + 50) })
    for (const game of games.values()) {
      const winner = gameHighlights(game.plays)[0]
      if (!winner) continue
      const key = `${game.seasonId}:${winner.player_id}`
      counts.set(key, (counts.get(key) ?? 0) + 1)
    }
  }
  return rows.map((row) => ({
    ...row,
    mvp_count: counts.get(`${row.season_id}:${row.player_id}`) ?? 0,
  }))
}

export async function fetchSeasonStatistics(seasonId: string): Promise<SeasonBattingStats[]> {
  assertConfigured()
  const { data, error } = await supabase
    .from('season_batting_stats')
    .select('*')
    .eq('season_id', seasonId)
    .order('player_name')

  if (error) throwQueryError('Unable to load batting statistics', error)
  return withMvpCounts(data.map(mapSeasonStats))
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
  for (const row of await withMvpCounts(data.map(mapSeasonStats))) {
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
  return withMvpCounts(data.map(mapSeasonStats))
}

export async function fetchAllSeasonStatistics(): Promise<SeasonBattingStats[]> {
  assertConfigured()
  const { data, error } = await supabase
    .from('season_batting_stats')
    .select('*')
    .order('season_name', { ascending: false })
    .order('player_name')

  if (error) throwQueryError('Unable to load all-time statistics', error)
  return withMvpCounts(data.map(mapSeasonStats))
}
