import { describe, expect, it } from 'vitest'

import type { SeasonBattingStats } from '@/types/domain'

import { safeDownloadFilename, sortStatistics, statisticsToCsv } from './statisticsTable'

function row(name: string, hits: number): SeasonBattingStats {
  return {
    season_id: 'season-1',
    season_name: 'Fall 2026',
    league_id: 'league-1',
    league_name: 'Monday Rec',
    league_slug: 'monday-rec',
    player_id: name,
    player_name: name,
    games: 1,
    plate_appearances: 4,
    at_bats: 4,
    hits,
    singles: hits,
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
    total_bases: hits,
    batting_average: hits / 4,
    on_base_percentage: hits / 4,
    slugging_percentage: hits / 4,
    ops: hits / 2,
  }
}

describe('statistics table tools', () => {
  it('sorts numeric columns descending with player name as the tie-breaker', () => {
    const rows = [row('Casey', 1), row('Alex', 3), row('Blair', 3)]
    expect(sortStatistics(rows, 'hits', 'desc').map((item) => item.player_name)).toEqual([
      'Alex',
      'Blair',
      'Casey',
    ])
  })

  it('creates an explicit, AI-friendly CSV and escapes player names', () => {
    const csv = statisticsToCsv([row('Jamie "Jet", Jr.', 2)])
    expect(csv).toContain('League,Season,Player,Games,Plate appearances,At bats')
    expect(csv).toContain('Monday Rec,Fall 2026,"Jamie ""Jet"", Jr.",1,4,4,2')
    expect(csv).toContain(',.500,.500,.500,1.000,')
  })

  it('normalizes descriptive download names', () => {
    expect(safeDownloadFilename('Monday Rec — Fall 2026 Batting Stats')).toBe(
      'monday-rec-fall-2026-batting-stats.csv',
    )
  })
})
