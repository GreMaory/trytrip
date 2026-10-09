const LOCALE = 'fr-FR'

export function formatDate(value: string | null | undefined, options: Intl.DateTimeFormatOptions = { dateStyle: 'medium' }): string {
  if (!value) return '—'
  // Plain dates ("2027-07-10") are local dates: never shift them through UTC.
  const date = /^\d{4}-\d{2}-\d{2}$/.test(value) ? parseISODate(value) : new Date(value)
  return new Intl.DateTimeFormat(LOCALE, options).format(date)
}

export function formatDateTime(value: string | null | undefined): string {
  return formatDate(value, { dateStyle: 'medium', timeStyle: 'short' })
}

/** Money values arrive as decimal strings and are only formatted, never computed in the browser. */
export function formatMoney(amount: string | number | null | undefined, currency = 'EUR'): string {
  if (amount === null || amount === undefined || amount === '') return '—'
  return new Intl.NumberFormat(LOCALE, { style: 'currency', currency }).format(Number(amount))
}

export function formatPercent(ratio: number): string {
  return new Intl.NumberFormat(LOCALE, { style: 'percent', maximumFractionDigits: 1 }).format(ratio)
}

export function parseISODate(value: string): Date {
  const [year, month, day] = value.split('-').map(Number)
  return new Date(year!, month! - 1, day!)
}

export function toISODate(date: Date): string {
  const pad = (n: number) => String(n).padStart(2, '0')
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`
}

export function addDays(value: string, days: number): string {
  const date = parseISODate(value)
  date.setDate(date.getDate() + days)
  return toISODate(date)
}

export function daysBetween(from: string, to: string): number {
  return Math.round((parseISODate(to).getTime() - parseISODate(from).getTime()) / 86_400_000)
}
