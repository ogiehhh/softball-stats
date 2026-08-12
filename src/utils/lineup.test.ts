import { describe, expect, it } from 'vitest'

import type { Player } from '@/types/domain'

import {
  addPlayerToLineup,
  moveLineupPlayer,
  nextBattingOrder,
  removePlayerFromLineup,
  validateLineupPlayerIds,
} from './lineup'

function player(id: string): Player {
  return {
    id,
    first_name: id,
    last_name: 'Test',
    display_name: `${id} Test`,
    active: true,
    created_at: '',
    updated_at: '',
  }
}

describe('lineup construction', () => {
  it('adds each player once and preserves order', () => {
    const ada = player('ada')
    const betty = player('betty')

    const lineup = addPlayerToLineup(addPlayerToLineup([ada], betty), ada)
    expect(lineup.map((entry) => entry.id)).toEqual(['ada', 'betty'])
  })

  it('moves and removes players without mutating the source lineup', () => {
    const original = [player('ada'), player('betty'), player('carla')]
    const moved = moveLineupPlayer(original, 2, 0)
    const removed = removePlayerFromLineup(moved, 'betty')

    expect(original.map((entry) => entry.id)).toEqual(['ada', 'betty', 'carla'])
    expect(moved.map((entry) => entry.id)).toEqual(['carla', 'ada', 'betty'])
    expect(removed.map((entry) => entry.id)).toEqual(['carla', 'ada'])
  })

  it('rejects empty, duplicate, and non-rostered lineups', () => {
    expect(validateLineupPlayerIds([], ['ada']).valid).toBe(false)
    expect(validateLineupPlayerIds(['ada', 'ada'], ['ada']).message).toContain('only once')
    expect(validateLineupPlayerIds(['ada', 'outsider'], ['ada']).message).toContain('season roster')
    expect(validateLineupPlayerIds(['ada'], ['ada']).valid).toBe(true)
  })
})

describe('batting-order cycling', () => {
  it('advances through the lineup and wraps to the leadoff batter', () => {
    expect(nextBattingOrder(1, 4)).toBe(2)
    expect(nextBattingOrder(3, 4)).toBe(4)
    expect(nextBattingOrder(4, 4)).toBe(1)
    expect(nextBattingOrder(1, 1)).toBe(1)
  })

  it('rejects invalid current positions and empty lineups', () => {
    expect(() => nextBattingOrder(1, 0)).toThrow('at least one')
    expect(() => nextBattingOrder(0, 4)).toThrow('outside')
    expect(() => nextBattingOrder(5, 4)).toThrow('outside')
  })
})
