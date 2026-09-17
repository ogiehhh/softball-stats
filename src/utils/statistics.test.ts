import { describe, expect, it } from 'vitest'

import type { SeasonBattingStats } from '@/types/domain'

import { formatDate } from './formatters'
import { aggregatePlayerStatistics, calculateBattingLine } from './statistics'

function statisticRow(overrides: Partial<SeasonBattingStats> = {}): SeasonBattingStats {
  return {
    mvp_count: 0,
    season_id: 'season-1',
    season_name: 'Spring',
    league_id: 'league-1',
    league_name: 'Rec League',
    league_slug: 'rec-league',
    player_id: 'player-1',
    player_name: 'Alex Player',
    games: 1,
    plate_appearances: 2,
    at_bats: 2,
    hits: 1,
    singles: 1,
    doubles: 0,
    triples: 0,
    home_runs: 0,
    walks: 0,
    hit_by_pitch: 0,
    strikeouts: 0,
    runs: 0,
    rbi: 0,
    sacrifice_flies: 0,
    fielders_choice: 0,
    reached_on_error: 0,
    total_bases: 1,
    batting_average: 0.5,
    on_base_percentage: 0.5,
    slugging_percentage: 0.5,
    ops: 1,
    ...overrides,
  }
}

describe('batting statistics rules', () => {
  it('excludes walks and hit-by-pitch from at-bats while including both in OBP', () => {
    const line = calculateBattingLine([
      { result: 'single' },
      { result: 'walk' },
      { result: 'hit_by_pitch' },
      { result: 'groundout' },
    ])

    expect(line.plate_appearances).toBe(4)
    expect(line.at_bats).toBe(2)
    expect(line.hits).toBe(1)
    expect(line.batting_average).toBe(0.5)
    expect(line.on_base_percentage).toBe(0.75)
  })

  it('excludes sacrifice flies from at-bats and includes them in the OBP denominator', () => {
    const line = calculateBattingLine([{ result: 'single' }, { result: 'sacrifice_fly', rbi: 1 }])

    expect(line.at_bats).toBe(1)
    expect(line.sacrifice_flies).toBe(1)
    expect(line.rbi).toBe(1)
    expect(line.on_base_percentage).toBe(0.5)
  })

  it('treats errors and fielder choices as at-bats but not hits', () => {
    const line = calculateBattingLine([
      { result: 'reached_on_error' },
      { result: 'fielders_choice' },
      { result: 'strikeout' },
    ])

    expect(line.at_bats).toBe(3)
    expect(line.hits).toBe(0)
    expect(line.reached_on_error).toBe(1)
    expect(line.fielders_choice).toBe(1)
    expect(line.strikeouts).toBe(1)
  })

  it('calculates total bases, slugging, runs, RBI, and OPS', () => {
    const line = calculateBattingLine([
      { result: 'single', runsScored: 1 },
      { result: 'double', rbi: 1 },
      { result: 'triple', rbi: 2 },
      { result: 'home_run', rbi: 1, runsScored: 1 },
    ])

    expect(line.total_bases).toBe(10)
    expect(line.slugging_percentage).toBe(2.5)
    expect(line.runs).toBe(2)
    expect(line.rbi).toBe(4)
    expect(line.ops).toBe(3.5)
  })

  it('returns zero rates when denominators are zero', () => {
    const line = calculateBattingLine([])

    expect(line.batting_average).toBe(0)
    expect(line.on_base_percentage).toBe(0)
    expect(line.slugging_percentage).toBe(0)
    expect(line.ops).toBe(0)
  })
})

describe('date formatting', () => {
  it('preserves date-only calendar values in the local timezone', () => {
    expect(formatDate('2026-09-01')).toBe('Sep 1, 2026')
  })
})

describe('all-time player aggregation', () => {
  it('sums season counts and recalculates rates from combined denominators', () => {
    const rows = aggregatePlayerStatistics([
      statisticRow({ mvp_count: 2 }),
      statisticRow({
        mvp_count: 3,
        season_id: 'season-2',
        season_name: 'Fall',
        at_bats: 1,
        plate_appearances: 2,
        hits: 0,
        singles: 0,
        walks: 1,
        total_bases: 0,
        batting_average: 0,
        on_base_percentage: 0.5,
        slugging_percentage: 0,
        ops: 0.5,
      }),
    ])

    expect(rows).toHaveLength(1)
    expect(rows[0]).toMatchObject({
      mvp_count: 5,
      season_id: 'all-time',
      league_name: 'All leagues',
      games: 2,
      plate_appearances: 4,
      at_bats: 3,
      hits: 1,
      walks: 1,
    })
    expect(rows[0]?.batting_average).toBeCloseTo(1 / 3)
    expect(rows[0]?.on_base_percentage).toBeCloseTo(0.5)
  })
})
