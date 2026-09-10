import type { BattingCounts, BattingRates, SeasonBattingStats } from '@/types/domain'
import { formatRate } from '@/utils/formatters'

export type StatisticValueKey = keyof BattingCounts | keyof BattingRates
export type StatisticSortKey = 'player_name' | StatisticValueKey

export interface StatisticColumn {
  key: StatisticValueKey
  label: string
  csvLabel: string
  rate?: boolean
}

export const statisticColumns: StatisticColumn[] = [
  { key: 'batting_average', label: 'AVG', csvLabel: 'Batting average', rate: true },
  { key: 'on_base_percentage', label: 'OBP', csvLabel: 'On-base percentage', rate: true },
  { key: 'slugging_percentage', label: 'SLG', csvLabel: 'Slugging percentage', rate: true },
  { key: 'ops', label: 'OPS', csvLabel: 'On-base plus slugging', rate: true },
  { key: 'games', label: 'G', csvLabel: 'Games' },
  { key: 'plate_appearances', label: 'PA', csvLabel: 'Plate appearances' },
  { key: 'at_bats', label: 'AB', csvLabel: 'At bats' },
  { key: 'hits', label: 'H', csvLabel: 'Hits' },
  { key: 'doubles', label: '2B', csvLabel: 'Doubles' },
  { key: 'triples', label: '3B', csvLabel: 'Triples' },
  { key: 'home_runs', label: 'HR', csvLabel: 'Home runs' },
  { key: 'runs', label: 'R', csvLabel: 'Runs' },
  { key: 'rbi', label: 'RBI', csvLabel: 'Runs batted in' },
  { key: 'walks', label: 'BB', csvLabel: 'Walks' },
  { key: 'strikeouts', label: 'K', csvLabel: 'Strikeouts' },
  { key: 'singles', label: '1B', csvLabel: 'Singles' },
  { key: 'sacrifice_flies', label: 'SF', csvLabel: 'Sacrifice flies' },
  { key: 'fielders_choice', label: 'FC', csvLabel: "Fielder's choice" },
  { key: 'reached_on_error', label: 'ROE', csvLabel: 'Reached on error' },
  { key: 'total_bases', label: 'TB', csvLabel: 'Total bases' },
]

export const simpleStatisticColumns: StatisticColumn[] = [
  { key: 'batting_average', label: 'AVG', csvLabel: 'Batting average', rate: true },
  { key: 'on_base_percentage', label: 'OBP', csvLabel: 'On-base percentage', rate: true },
  { key: 'rbi', label: 'RBIs', csvLabel: 'Runs batted in' },
  { key: 'home_runs', label: 'HRs', csvLabel: 'Home runs' },
]

export function sortStatistics(
  rows: SeasonBattingStats[],
  key: StatisticSortKey,
  direction: 'asc' | 'desc',
): SeasonBattingStats[] {
  const multiplier = direction === 'asc' ? 1 : -1
  return [...rows].sort((left, right) => {
    if (key === 'player_name') {
      return (
        left.player_name.localeCompare(right.player_name, undefined, { sensitivity: 'base' }) *
        multiplier
      )
    }
    const difference = left[key] - right[key]
    if (difference !== 0) return difference * multiplier
    return left.player_name.localeCompare(right.player_name, undefined, { sensitivity: 'base' })
  })
}

function escapeCsv(value: string | number): string {
  const text = String(value)
  return /[",\r\n]/.test(text) ? `"${text.replaceAll('"', '""')}"` : text
}

export function statisticsToCsv(
  rows: SeasonBattingStats[],
  columns: StatisticColumn[] = statisticColumns,
): string {
  const headers = ['League', 'Season', 'Player', ...columns.map((column) => column.csvLabel)]
  const lines = rows.map((row) => [
    row.league_name,
    row.season_name,
    row.player_name,
    ...columns.map((column) => (column.rate ? formatRate(row[column.key]) : row[column.key])),
  ])
  return [headers, ...lines].map((line) => line.map(escapeCsv).join(',')).join('\r\n') + '\r\n'
}

export function safeDownloadFilename(value: string): string {
  const safe = value
    .trim()
    .toLocaleLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
  return `${safe || 'softball-batting-stats'}.csv`
}
