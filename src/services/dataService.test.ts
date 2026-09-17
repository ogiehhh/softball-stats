import { beforeEach, describe, expect, it, vi } from 'vitest'

const { execute, calls } = vi.hoisted(() => ({
  execute: vi.fn(),
  calls: [] as { table: string; filters: unknown[][] }[],
}))
vi.mock('@/lib/supabase', () => ({
  isSupabaseConfigured: true,
  supabase: {
    from(table: string) {
      const call = { table, filters: [] as unknown[][] }
      calls.push(call)
      const query = {
        select: () => query,
        eq: (...args: unknown[]) => {
          call.filters.push(['eq', ...args])
          return query
        },
        is: (...args: unknown[]) => {
          call.filters.push(['is', ...args])
          return query
        },
        in: (...args: unknown[]) => {
          call.filters.push(['in', ...args])
          return query
        },
        order: () => query,
        range: (...args: unknown[]) => {
          call.filters.push(['range', ...args])
          return query
        },
        then: (resolve: (value: unknown) => unknown) =>
          Promise.resolve(execute(table)).then(resolve),
      }
      return query
    },
  },
}))
import { fetchSeasonStatistics, fetchLeagueStatistics, fetchGameHighlights } from './dataService'

const person = (name: string) => ({ first_name: name, last_name: '', display_name: name })
const play = (game: string, player: string, result = 'single') => ({
  game_id: game,
  player_id: player,
  result,
  rbi: 0,
  games: { season_id: 'season-1' },
  players: person(player),
  runner_advancements: [],
})
const rows = ['Alex', 'Blair', 'Casey'].map((player) => ({
  player_id: player,
  player_name: player,
  season_id: 'season-1',
}))

beforeEach(() => {
  execute.mockReset()
  calls.length = 0
})
describe('game MVP statistics', () => {
  it('counts one winner per completed game using the highlights ranking, with zero for non-winners', async () => {
    execute.mockImplementation((table) => ({
      data:
        table === 'season_batting_stats'
          ? rows
          : [
              play('g1', 'Alex'),
              play('g1', 'Blair', 'home_run'),
              play('g2', 'Alex'),
              play('g2', 'Blair'),
              play('g3', 'Alex', 'double'),
            ],
      error: null,
    }))
    const stats = await fetchSeasonStatistics('season-1')
    expect(stats.map((row) => row.mvp_count)).toEqual([2, 1, 0])
    const filters = calls.find((call) => call.table === 'plate_appearances')!.filters
    expect(filters).toEqual(
      expect.arrayContaining([
        ['eq', 'games.status', 'completed'],
        ['is', 'games.archived_at', null],
        ['is', 'games.seasons.archived_at', null],
        ['is', 'games.seasons.leagues.archived_at', null],
        ['in', 'games.season_id', ['season-1']],
      ]),
    )
    expect((await fetchGameHighlights('g1'))[0]?.player_id).toBe('Blair')
  })
  it('finishes a game across page boundaries before choosing its MVP', async () => {
    execute
      .mockResolvedValueOnce({ data: rows, error: null })
      .mockResolvedValueOnce({
        data: Array.from({ length: 500 }, () => play('g1', 'Alex', 'groundout')),
        error: null,
      })
      .mockResolvedValueOnce({ data: [play('g1', 'Blair', 'home_run')], error: null })
    expect((await fetchSeasonStatistics('season-1')).map((row) => row.mvp_count)).toEqual([0, 1, 0])
    expect(calls.at(-1)!.filters).toContainEqual(['range', 500, 999])
  })
  it('sums MVP awards across seasons in league totals', async () => {
    execute
      .mockResolvedValueOnce({
        data: [rows[0], { ...rows[0], season_id: 'season-2' }],
        error: null,
      })
      .mockResolvedValueOnce({
        data: [play('g1', 'Alex'), { ...play('g2', 'Alex'), games: { season_id: 'season-2' } }],
        error: null,
      })
    expect((await fetchLeagueStatistics('league-1'))[0]?.mvp_count).toBe(2)
  })
  it('surfaces a failed awards request instead of silently showing zero awards', async () => {
    execute
      .mockResolvedValueOnce({ data: rows, error: null })
      .mockResolvedValueOnce({ data: null, error: { message: 'offline' } })
    await expect(fetchSeasonStatistics('season-1')).rejects.toThrow(
      'Unable to load game highlights: offline',
    )
  })
})
