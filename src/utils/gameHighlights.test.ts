import { describe, expect, it } from 'vitest'
import { gameHighlights, type HighlightPlay } from './gameHighlights'

function play(
  name: string,
  result: HighlightPlay['result'],
  rbi = 0,
  scorers: string[] = [],
): HighlightPlay {
  return {
    player_id: name,
    player_name: name,
    result,
    rbi,
    scorers: scorers.map((name) => ({ player_id: name, player_name: name })),
  }
}

describe('game highlights', () => {
  it('ranks three distinct players by offensive contribution and credits runs to runners', () => {
    const highlights = gameHighlights([
      play('Alex', 'single'),
      play('Blair', 'home_run', 2, ['Alex', 'Blair']),
      play('Casey', 'double'),
      play('Drew', 'strikeout'),
      play('Alex', 'walk'),
    ])
    expect(highlights.map((line) => line.player_name)).toEqual(['Blair', 'Alex', 'Casey'])
    expect(highlights[0]).toMatchObject({ impact: 7, runs: 1, rbi: 2, home_runs: 1 })
    expect(highlights[1]).toMatchObject({ runs: 1, hits: 1, walks: 1, at_bats: 1 })
    expect(highlights[0]?.summary).toBe('1-for-1 · 1 home run · 2 RBIs · 1 run scored')
  })

  it('breaks impact ties using OPS before name', () => {
    const highlights = gameHighlights([
      play('Alex', 'single'),
      play('Alex', 'groundout'),
      play('Blair', 'single'),
    ])
    expect(highlights.map((line) => line.player_name)).toEqual(['Blair', 'Alex'])
  })

  it('returns only recorded players, including runners without a plate appearance', () => {
    expect(gameHighlights([])).toEqual([])
    const highlights = gameHighlights([play('Blair', 'sacrifice_fly', 1, ['Alex'])])
    expect(highlights).toHaveLength(2)
    expect(highlights.find((line) => line.player_name === 'Alex')?.runs).toBe(1)
  })
})
