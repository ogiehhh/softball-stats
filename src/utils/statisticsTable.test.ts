import { describe, expect, it } from 'vitest'

import type { SeasonBattingStats } from '@/types/domain'

import {
  safeDownloadFilename,
  simpleStatisticColumns,
  sortStatistics,
  statisticColumns,
  statisticsToCsv,
} from './statisticsTable'

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
    expect(csv).toContain(
      'League,Season,Player,Batting average,Slugging percentage,On-base percentage,Games',
    )
    expect(csv).toContain('Monday Rec,Fall 2026,"Jamie ""Jet"", Jr.",.500,.500,.500,1,4,4,2')
    expect(csv).not.toMatch(/HBP|Hit by pitch/i)
    expect(statisticColumns.slice(0, 3).map((column) => column.label)).toEqual([
      'AVG',
      'SLG',
      'OBP',
    ])
  })

  it('exports only the four displayed statistics in simple view', () => {
    const csv = statisticsToCsv([row('Alex', 2)], simpleStatisticColumns)
    expect(csv).toBe(
      'League,Season,Player,Batting average,On-base percentage,Runs batted in,Home runs\r\nMonday Rec,Fall 2026,Alex,.500,.500,0,0\r\n',
    )
  })

  it('normalizes descriptive download names', () => {
    expect(safeDownloadFilename('Monday Rec — Fall 2026 Batting Stats')).toBe(
      'monday-rec-fall-2026-batting-stats.csv',
    )
  })
})
