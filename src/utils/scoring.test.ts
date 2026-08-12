import { describe, expect, it } from 'vitest'

import type { BaseOccupancy } from '@/types/domain'
import {
  allowedDestinations,
  countOuts,
  countRuns,
  createDefaultRunnerOutcomes,
  defaultRbi,
  validateRunnerOutcomes,
} from '@/utils/scoring'

const emptyBases: BaseOccupancy = { first: null, second: null, third: null }

describe('scoring defaults', () => {
  it('places a single on first and advances existing runners one base', () => {
    const outcomes = createDefaultRunnerOutcomes('single', 'batter', {
      first: 'first-runner',
      second: 'second-runner',
      third: 'third-runner',
    })

    expect(outcomes).toEqual([
      { playerId: 'third-runner', startingBase: 'third', endingBase: 'home' },
      { playerId: 'second-runner', startingBase: 'second', endingBase: 'third' },
      { playerId: 'first-runner', startingBase: 'first', endingBase: 'second' },
      { playerId: 'batter', startingBase: 'batter', endingBase: 'first' },
    ])
    expect(countRuns(outcomes)).toBe(1)
  })

  it('only forces occupied runners on a walk', () => {
    expect(
      createDefaultRunnerOutcomes('walk', 'batter', {
        first: 'first-runner',
        second: null,
        third: 'third-runner',
      }),
    ).toEqual([
      { playerId: 'third-runner', startingBase: 'third', endingBase: 'third' },
      { playerId: 'first-runner', startingBase: 'first', endingBase: 'second' },
      { playerId: 'batter', startingBase: 'batter', endingBase: 'first' },
    ])

    const loadedWalk = createDefaultRunnerOutcomes('walk', 'batter', {
      first: 'one',
      second: 'two',
      third: 'three',
    })
    expect(loadedWalk.map((outcome) => outcome.endingBase)).toEqual([
      'home',
      'third',
      'second',
      'first',
    ])
  })

  it('scores every runner and the batter on a home run', () => {
    const outcomes = createDefaultRunnerOutcomes('home_run', 'batter', {
      first: 'one',
      second: 'two',
      third: null,
    })
    expect(countRuns(outcomes)).toBe(3)
    expect(defaultRbi('home_run', outcomes)).toBe(3)
    expect(allowedDestinations('batter', 'home_run')).toEqual(['home'])
  })

  it('defaults a fielder choice to an out on the runner from first', () => {
    const outcomes = createDefaultRunnerOutcomes('fielders_choice', 'batter', {
      first: 'one',
      second: 'two',
      third: null,
    })
    expect(outcomes).toEqual([
      { playerId: 'two', startingBase: 'second', endingBase: 'second' },
      { playerId: 'one', startingBase: 'first', endingBase: 'out' },
      { playerId: 'batter', startingBase: 'batter', endingBase: 'first' },
    ])
    expect(countOuts(outcomes)).toBe(1)
  })

  it('derives outs and lets a runner create a multi-out play', () => {
    const outcomes = createDefaultRunnerOutcomes('lineout', 'batter', {
      ...emptyBases,
      first: 'runner',
    })
    outcomes[0]!.endingBase = 'out'
    expect(countOuts(outcomes)).toBe(2)
    expect(validateRunnerOutcomes(outcomes, 1, 0)).toBe('')
    expect(validateRunnerOutcomes(outcomes, 2, 0)).toContain('more than three outs')
  })

  it('rejects duplicate final bases and too many RBI', () => {
    const outcomes = createDefaultRunnerOutcomes('single', 'batter', {
      ...emptyBases,
      first: 'runner',
    })
    outcomes[0]!.endingBase = 'first'
    expect(validateRunnerOutcomes(outcomes, 0, 0)).toContain('same base')

    outcomes[0]!.endingBase = 'home'
    expect(validateRunnerOutcomes(outcomes, 0, 2)).toBe('RBI must be between 0 and 1.')
  })

  it('defaults RBI to zero on an error even when a runner scores', () => {
    const outcomes = createDefaultRunnerOutcomes('reached_on_error', 'batter', {
      ...emptyBases,
      third: 'runner',
    })
    expect(countRuns(outcomes)).toBe(1)
    expect(defaultRbi('reached_on_error', outcomes)).toBe(0)
  })
})
