import { describe, expect, it } from 'vitest'
import { currentSubdomain, hostKind } from '@/utils/host'
import { addDays, daysBetween, formatDate, formatMoney } from '@/utils/format'

describe('host', () => {
  it('detects the tenant, portal and admin contexts', () => {
    expect(hostKind('acme.lvh.me')).toBe('tenant')
    expect(currentSubdomain('acme.lvh.me')).toBe('acme')
    expect(hostKind('app.lvh.me')).toBe('portal')
    expect(hostKind('www.lvh.me')).toBe('portal')
    expect(hostKind('lvh.me')).toBe('portal')
    expect(hostKind('localhost')).toBe('portal')
    expect(hostKind('admin.lvh.me')).toBe('admin')
    expect(hostKind('evil-lvh.me')).toBe('portal')
  })
})

describe('format', () => {
  it('formats plain dates without time zone shifts', () => {
    expect(formatDate('2027-07-01')).toBe('1 juil. 2027')
  })

  it('computes nights between local dates', () => {
    expect(daysBetween('2027-03-27', '2027-03-29')).toBe(2) // across a DST change
    expect(addDays('2027-12-31', 1)).toBe('2028-01-01')
  })

  it('formats decimal strings as money', () => {
    expect(formatMoney('1000.5', 'EUR').replace(/\s/g, ' ')).toBe('1 000,50 €')
    expect(formatMoney(null)).toBe('—')
  })
})
