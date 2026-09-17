import type { BattingCounts, BattingRates, PlateAppearanceResult } from '@/types/domain'
import { calculateBattingLine } from '@/utils/statistics'

export interface HighlightPlay {
  player_id: string
  player_name: string
  result: PlateAppearanceResult
  rbi: number
  scorers: { player_id: string; player_name: string }[]
}

export interface GameHighlight extends BattingCounts, BattingRates {
  player_id: string
  player_name: string
  impact: number
  summary: string
}

function describeLine(line: BattingCounts): string {
  const details = [`${line.hits}-for-${line.at_bats}`]
  const stats: [number, string, string][] = [
    [line.doubles, 'double', 'doubles'],
    [line.triples, 'triple', 'triples'],
    [line.home_runs, 'home run', 'home runs'],
    [line.walks, 'walk', 'walks'],
    [line.hit_by_pitch, 'hit by pitch', 'hit by pitches'],
    [line.rbi, 'RBI', 'RBIs'],
    [line.runs, 'run scored', 'runs scored'],
  ]
  for (const [count, singular, plural] of stats) {
    if (count) details.push(`${count} ${count === 1 ? singular : plural}`)
  }
  return details.join(' · ')
}

export function gameHighlights(plays: HighlightPlay[]): GameHighlight[] {
  const players = new Map<string, { name: string; plays: HighlightPlay[]; runs: number }>()
  function player(id: string, name: string) {
    let entry = players.get(id)
    if (!entry) {
      entry = { name, plays: [], runs: 0 }
      players.set(id, entry)
    }
    return entry
  }
  for (const play of plays) {
    player(play.player_id, play.player_name).plays.push(play)
    for (const scorer of play.scorers) player(scorer.player_id, scorer.player_name).runs += 1
  }
  return Array.from(players, ([id, entry]) => {
    const line = { ...calculateBattingLine(entry.plays), runs: entry.runs }
    // A transparent game contribution score; OPS breaks equal contribution totals.
    const impact = line.total_bases + line.walks + line.hit_by_pitch + line.runs + line.rbi
    return {
      ...line,
      player_id: id,
      player_name: entry.name,
      impact,
      summary: describeLine(line),
    }
  })
    .sort(
      (a, b) =>
        b.impact - a.impact ||
        b.ops - a.ops ||
        a.player_name.localeCompare(b.player_name) ||
        a.player_id.localeCompare(b.player_id),
    )
    .slice(0, 3)
}
