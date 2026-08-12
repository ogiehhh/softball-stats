import { describe, expect, it } from 'vitest'

import { formatDate } from './formatters'
import { calculateBattingLine } from './statistics'

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
