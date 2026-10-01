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
import {
  fetchSeasonStatistics,
  fetchLeagueStatistics,
  fetchGameHighlights,
  fetchPlayerGames,
} from './dataService'

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

describe('player game history', () => {
  it('keeps batting results in order and counts runs from other batters separately', async () => {
    const game = { id: 'g1', played_at: '2026-09-23T23:00:00Z' }
    execute.mockImplementation((table) => ({
      data:
        table === 'plate_appearances'
          ? ['single', 'walk', 'groundout', 'sacrifice_fly', 'strikeout'].map((result, index) => ({
              id: `pa${index}`,
              result,
              rbi: result === 'sacrifice_fly' ? 1 : 0,
              games: game,
            }))
          : [
              { id: 'run1', plate_appearances: { game_id: 'g1' } },
              { id: 'archived-run', plate_appearances: { game_id: 'archived-game' } },
            ],
      error: null,
    }))
    const [line] = await fetchPlayerGames('Alex')
    expect(line).toMatchObject({ hits: 1, at_bats: 3, runs: 1, rbi: 1, walks: 1 })
    expect(line?.plays.map((play) => play.result)).toEqual([
      'single',
      'walk',
      'groundout',
      'sacrifice_fly',
      'strikeout',
    ])
    expect(calls[0]?.filters).toEqual(
      expect.arrayContaining([
        ['eq', 'player_id', 'Alex'],
        ['is', 'games.archived_at', null],
        ['is', 'games.seasons.archived_at', null],
        ['is', 'games.seasons.leagues.archived_at', null],
      ]),
    )
  })

  it('continues across page boundaries and sorts games newest first', async () => {
    execute
      .mockResolvedValueOnce({
        data: Array.from({ length: 500 }, (_, index) => ({
          id: `pa${index}`,
          result: 'single',
          rbi: 0,
          games: { id: 'older', played_at: '2025-09-23T23:00:00Z' },
        })),
        error: null,
      })
      .mockResolvedValueOnce({
        data: [
          {
            id: 'latest',
            result: 'walk',
            rbi: 0,
            games: { id: 'newer', played_at: '2026-09-23T23:00:00Z' },
          },
        ],
        error: null,
      })
      .mockResolvedValueOnce({ data: [], error: null })
    const games = await fetchPlayerGames('Alex')
    expect(games.map((line) => line.game.id)).toEqual(['newer', 'older'])
    expect(games[1]?.hits).toBe(500)
    expect(calls[1]?.filters).toContainEqual(['range', 500, 999])
  })
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
