import type {
  BattingCounts,
  BattingRates,
  PlateAppearanceResult,
  SeasonBattingStats,
} from '@/types/domain'

const atBatResults = new Set<PlateAppearanceResult>([
  'single',
  'double',
  'triple',
  'home_run',
  'strikeout',
  'groundout',
  'flyout',
  'lineout',
  'popout',
  'fielders_choice',
  'reached_on_error',
])

const hitBases: Partial<Record<PlateAppearanceResult, number>> = {
  single: 1,
  double: 2,
  triple: 3,
  home_run: 4,
}

export interface ScoringFixtureEvent {
  result: PlateAppearanceResult
  rbi?: number
  runsScored?: number
}

export function calculateRates(counts: BattingCounts): BattingRates {
  const average = counts.at_bats ? counts.hits / counts.at_bats : 0
  const obpDenominator =
    counts.at_bats + counts.walks + counts.hit_by_pitch + counts.sacrifice_flies
  const onBase = obpDenominator
    ? (counts.hits + counts.walks + counts.hit_by_pitch) / obpDenominator
    : 0
  const slugging = counts.at_bats ? counts.total_bases / counts.at_bats : 0

  return {
    batting_average: average,
    on_base_percentage: onBase,
    slugging_percentage: slugging,
    ops: onBase + slugging,
  }
}

export function calculateBattingLine(events: ScoringFixtureEvent[]): BattingCounts & BattingRates {
  const counts: BattingCounts = {
    games: 0,
    plate_appearances: events.length,
    at_bats: 0,
    hits: 0,
    singles: 0,
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
    total_bases: 0,
  }

  for (const event of events) {
    if (atBatResults.has(event.result)) counts.at_bats += 1

    const bases = hitBases[event.result] ?? 0
    if (bases) {
      counts.hits += 1
      counts.total_bases += bases
    }

    if (event.result === 'single') counts.singles += 1
    if (event.result === 'double') counts.doubles += 1
    if (event.result === 'triple') counts.triples += 1
    if (event.result === 'home_run') counts.home_runs += 1
    if (event.result === 'walk') counts.walks += 1
    if (event.result === 'hit_by_pitch') counts.hit_by_pitch += 1
    if (event.result === 'strikeout') counts.strikeouts += 1
    if (event.result === 'sacrifice_fly') counts.sacrifice_flies += 1
    if (event.result === 'fielders_choice') counts.fielders_choice += 1
    if (event.result === 'reached_on_error') counts.reached_on_error += 1

    counts.rbi += event.rbi ?? 0
    counts.runs += event.runsScored ?? 0
  }

  return { ...counts, ...calculateRates(counts) }
}

export function aggregateSeasonStats(
  lines: SeasonBattingStats[],
): BattingCounts & BattingRates & { mvp_count: number } {
  const counts = lines.reduce<BattingCounts>(
    (total, line) => ({
      games: total.games + line.games,
      plate_appearances: total.plate_appearances + line.plate_appearances,
      at_bats: total.at_bats + line.at_bats,
      hits: total.hits + line.hits,
      singles: total.singles + line.singles,
      doubles: total.doubles + line.doubles,
      triples: total.triples + line.triples,
      home_runs: total.home_runs + line.home_runs,
      walks: total.walks + line.walks,
      hit_by_pitch: total.hit_by_pitch + line.hit_by_pitch,
      strikeouts: total.strikeouts + line.strikeouts,
      runs: total.runs + line.runs,
      rbi: total.rbi + line.rbi,
      sacrifice_flies: total.sacrifice_flies + line.sacrifice_flies,
      fielders_choice: total.fielders_choice + line.fielders_choice,
      reached_on_error: total.reached_on_error + line.reached_on_error,
      total_bases: total.total_bases + line.total_bases,
    }),
    {
      games: 0,
      plate_appearances: 0,
      at_bats: 0,
      hits: 0,
      singles: 0,
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
      total_bases: 0,
    },
  )

  return {
    ...counts,
    ...calculateRates(counts),
    mvp_count: lines.reduce((total, line) => total + line.mvp_count, 0),
  }
}

export function aggregatePlayerStatistics(lines: SeasonBattingStats[]): SeasonBattingStats[] {
  const playerLines = new Map<string, SeasonBattingStats[]>()
  for (const line of lines) {
    const group = playerLines.get(line.player_id) ?? []
    group.push(line)
    playerLines.set(line.player_id, group)
  }

  return Array.from(playerLines.values())
    .map((group) => {
      const first = group[0]
      if (!first) throw new Error('A statistic is missing its player.')
      return {
        ...first,
        season_id: 'all-time',
        season_name: 'All time',
        league_id: 'all-leagues',
        league_name: 'All leagues',
        league_slug: '',
        ...aggregateSeasonStats(group),
      }
    })
    .sort((left, right) => left.player_name.localeCompare(right.player_name))
}
