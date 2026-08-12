import type { GameStatus } from '@/types/domain'

const dateFormatter = new Intl.DateTimeFormat('en-US', {
  month: 'short',
  day: 'numeric',
  year: 'numeric',
})

export function formatDate(value: string | null): string {
  if (!value) return 'Date TBD'

  const dateOnlyMatch = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value)
  if (dateOnlyMatch) {
    const [, year, month, day] = dateOnlyMatch
    return dateFormatter.format(new Date(Number(year), Number(month) - 1, Number(day)))
  }

  return dateFormatter.format(new Date(value))
}

export function formatRate(value: number): string {
  return Number(value).toFixed(3).replace(/^0/, '')
}

export function statusLabel(status: GameStatus): string {
  return {
    draft: 'Draft',
    in_progress: 'Live',
    completed: 'Final',
  }[status]
}

export function statusColor(status: GameStatus): string {
  return {
    draft: 'default',
    in_progress: 'warning',
    completed: 'success',
  }[status]
}
