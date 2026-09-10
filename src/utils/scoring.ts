import type {
  BaseDestination,
  BaseOccupancy,
  BaseOrigin,
  PlateAppearanceResult,
  RunnerOutcome,
} from '@/types/domain'

export const RESULT_LABELS: Record<PlateAppearanceResult, string> = {
  single: 'Single',
  double: 'Double',
  triple: 'Triple',
  home_run: 'Home run',
  walk: 'Walk',
  // Preserve old event history without offering this retired scoring result.
  hit_by_pitch: 'Reached base',
  strikeout: 'Strikeout',
  groundout: 'Groundout',
  flyout: 'Flyout',
  lineout: 'Lineout',
  popout: 'Popout',
  sacrifice_fly: 'Sac fly',
  fielders_choice: "Fielder's choice",
  reached_on_error: 'Reached on error',
}

export const DESTINATION_LABELS: Record<BaseDestination, string> = {
  first: '1B',
  second: '2B',
  third: '3B',
  home: 'Run',
  out: 'Out',
}

const OUT_RESULTS: PlateAppearanceResult[] = [
  'strikeout',
  'groundout',
  'flyout',
  'lineout',
  'popout',
  'sacrifice_fly',
]

const occupiedOrigins: Array<Exclude<BaseOrigin, 'batter'>> = ['third', 'second', 'first']

function playerAt(bases: BaseOccupancy, origin: Exclude<BaseOrigin, 'batter'>): string | null {
  return bases[origin]
}

function holdDestination(origin: Exclude<BaseOrigin, 'batter'>): BaseDestination {
  return origin
}

function oneBaseDestination(origin: Exclude<BaseOrigin, 'batter'>): BaseDestination {
  if (origin === 'first') return 'second'
  if (origin === 'second') return 'third'
  return 'home'
}

function batterDestination(result: PlateAppearanceResult): BaseDestination {
  if (result === 'double') return 'second'
  if (result === 'triple') return 'third'
  if (result === 'home_run') return 'home'
  if (OUT_RESULTS.includes(result)) return 'out'
  return 'first'
}

function existingRunnerDestination(
  result: PlateAppearanceResult,
  origin: Exclude<BaseOrigin, 'batter'>,
  bases: BaseOccupancy,
): BaseDestination {
  if (result === 'home_run' || result === 'triple') return 'home'
  if (result === 'double') return origin === 'first' ? 'third' : 'home'
  if (result === 'single' || result === 'groundout' || result === 'reached_on_error') {
    return oneBaseDestination(origin)
  }
  if (result === 'sacrifice_fly') return origin === 'third' ? 'home' : holdDestination(origin)

  if (result === 'walk') {
    if (origin === 'first') return 'second'
    if (origin === 'second' && bases.first) return 'third'
    if (origin === 'third' && bases.first && bases.second) return 'home'
  }

  return holdDestination(origin)
}

export function createDefaultRunnerOutcomes(
  result: PlateAppearanceResult,
  batterId: string,
  bases: BaseOccupancy,
  currentOuts = 0,
): RunnerOutcome[] {
  const outcomes: RunnerOutcome[] = occupiedOrigins.flatMap((origin) => {
    const playerId = playerAt(bases, origin)
    if (!playerId) return []
    return [
      {
        playerId,
        startingBase: origin,
        endingBase: existingRunnerDestination(result, origin, bases),
      } satisfies RunnerOutcome,
    ]
  })

  if (result === 'fielders_choice') {
    const runnerOut =
      [...outcomes].reverse().find((outcome) => outcome.startingBase === 'first') ??
      outcomes.find((outcome) => outcome.startingBase === 'third') ??
      outcomes.find((outcome) => outcome.startingBase === 'second')
    if (runnerOut) runnerOut.endingBase = 'out'
  }

  outcomes.push({
    playerId: batterId,
    startingBase: 'batter',
    endingBase: batterDestination(result),
  })
  if (currentOuts + countOuts(outcomes) >= 3) holdSurvivingRunners(outcomes)
  return outcomes
}

/** An inning-ending play needs explicit run credit after the third out is selected. */
export function holdSurvivingRunners(outcomes: RunnerOutcome[]): void {
  for (const outcome of outcomes) {
    if (outcome.startingBase !== 'batter' && outcome.endingBase !== 'out') {
      outcome.endingBase = outcome.startingBase
    }
  }
}

export function allowedDestinations(
  origin: BaseOrigin,
  result: PlateAppearanceResult,
): BaseDestination[] {
  if (origin === 'batter') {
    if (result === 'home_run') return ['home']
    if (OUT_RESULTS.includes(result)) return ['out']
    if (result === 'triple') return ['third', 'home', 'out']
    if (result === 'double') return ['second', 'third', 'home', 'out']
    return ['first', 'second', 'third', 'home', 'out']
  }

  if (origin === 'first') return ['first', 'second', 'third', 'home', 'out']
  if (origin === 'second') return ['second', 'third', 'home', 'out']
  return ['third', 'home', 'out']
}

export function countOuts(outcomes: RunnerOutcome[]): number {
  return outcomes.filter((outcome) => outcome.endingBase === 'out').length
}

export function countRuns(outcomes: RunnerOutcome[]): number {
  return outcomes.filter((outcome) => outcome.endingBase === 'home').length
}

export function defaultRbi(result: PlateAppearanceResult, outcomes: RunnerOutcome[]): number {
  return result === 'reached_on_error' ? 0 : countRuns(outcomes)
}

export function validateRunnerOutcomes(
  outcomes: RunnerOutcome[],
  currentOuts: number,
  rbi: number,
): string {
  const destinations = outcomes
    .map((outcome) => outcome.endingBase)
    .filter((destination) => ['first', 'second', 'third'].includes(destination))

  const outs = countOuts(outcomes)
  // Held runners are left on base; there is no next base occupancy after the third out.
  if (currentOuts + outs < 3 && new Set(destinations).size !== destinations.length) {
    return 'Two runners cannot finish on the same base.'
  }

  if (outs > 3 - currentOuts) return 'This play records more than three outs in the inning.'

  const runs = countRuns(outcomes)
  if (!Number.isInteger(rbi) || rbi < 0 || rbi > runs) {
    return `RBI must be between 0 and ${runs}.`
  }

  return ''
}
