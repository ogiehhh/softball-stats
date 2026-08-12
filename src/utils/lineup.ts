import type { Player } from '@/types/domain'

export interface LineupValidation {
  valid: boolean
  message: string
}

export function validateLineupPlayerIds(
  lineupPlayerIds: string[],
  rosterPlayerIds: string[],
): LineupValidation {
  if (lineupPlayerIds.length === 0) {
    return { valid: false, message: 'Add at least one rostered player to the lineup.' }
  }

  if (new Set(lineupPlayerIds).size !== lineupPlayerIds.length) {
    return { valid: false, message: 'A player can appear only once in the lineup.' }
  }

  const roster = new Set(rosterPlayerIds)
  if (lineupPlayerIds.some((playerId) => !roster.has(playerId))) {
    return { valid: false, message: 'Every lineup player must be on this season roster.' }
  }

  return { valid: true, message: '' }
}

export function addPlayerToLineup(lineup: Player[], player: Player): Player[] {
  if (lineup.some((entry) => entry.id === player.id)) return lineup
  return [...lineup, player]
}

export function removePlayerFromLineup(lineup: Player[], playerId: string): Player[] {
  return lineup.filter((player) => player.id !== playerId)
}

export function moveLineupPlayer(lineup: Player[], fromIndex: number, toIndex: number): Player[] {
  if (
    fromIndex < 0 ||
    toIndex < 0 ||
    fromIndex >= lineup.length ||
    toIndex >= lineup.length ||
    fromIndex === toIndex
  ) {
    return lineup
  }

  const reordered = [...lineup]
  const [player] = reordered.splice(fromIndex, 1)
  if (!player) return lineup
  reordered.splice(toIndex, 0, player)
  return reordered
}

export function nextBattingOrder(currentOrder: number, lineupSize: number): number {
  if (!Number.isInteger(lineupSize) || lineupSize < 1) {
    throw new Error('Lineup size must be at least one.')
  }

  if (!Number.isInteger(currentOrder) || currentOrder < 1 || currentOrder > lineupSize) {
    throw new Error('Current batting order is outside the lineup.')
  }

  return currentOrder === lineupSize ? 1 : currentOrder + 1
}
