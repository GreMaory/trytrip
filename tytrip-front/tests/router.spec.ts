import { beforeEach, describe, expect, it, vi } from 'vitest'
import { createPinia, setActivePinia } from 'pinia'
import type { RouteLocationNormalized } from 'vue-router'
import { accessGuard } from '@/router'
import { useAuthStore } from '@/stores/auth'
import type { Me } from '@/api/types'

vi.mock('@/utils/host', () => ({ hostKind: vi.fn(() => 'tenant') }))
import { hostKind } from '@/utils/host'

function route(path: string, meta: RouteLocationNormalized['meta'] = {}): RouteLocationNormalized {
  return { path, fullPath: path, meta } as RouteLocationNormalized
}

function signIn(permissions: string[], extra: Partial<Me> = {}) {
  const auth = useAuthStore()
  auth.loaded = true
  auth.me = {
    id: 1, name: 'Jane', email: 'jane@example.com', locale: 'fr', time_zone: 'Europe/Paris', preferences: {}, last_sign_in_at: null,
    email_verified: true, mfa_enabled: false, platform_admin: false, organizations: [],
    current_organization: { id: 1, name: 'Acme', subdomain: 'acme', status: 'active', time_zone: 'Europe/Paris', locale: 'fr', currency: 'EUR',
      host: 'acme.lvh.me', created_at: '', membership_id: 1, role: { id: 1, key: 'staff', name: 'Équipe' }, permissions },
    ...extra,
  }
}

describe('accessGuard', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    vi.mocked(hostKind).mockReturnValue('tenant')
  })

  it('sends anonymous users to the login page with a redirect', async () => {
    useAuthStore().loaded = true
    expect(await accessGuard(route('/reservations', { context: 'tenant' }))).toEqual({ name: 'login', query: { redirect: '/reservations' } })
  })

  it('lets anonymous users reach public pages and bounces signed-in users from the login page', async () => {
    useAuthStore().loaded = true
    expect(await accessGuard(route('/login', { public: true, guestOnly: true }))).toBe(true)
    signIn([])
    expect(await accessGuard(route('/login', { public: true, guestOnly: true }))).toEqual({ name: 'home' })
  })

  it('checks permissions', async () => {
    signIn(['reservations.read'])
    expect(await accessGuard(route('/reservations', { context: 'tenant', permission: 'reservations.read' }))).toBe(true)
    expect(await accessGuard(route('/settings/members', { context: 'tenant', permission: 'members.read' }))).toEqual({ name: 'forbidden' })
  })

  it('requires an organization subdomain for tenant pages', async () => {
    signIn(['reservations.read'])
    vi.mocked(hostKind).mockReturnValue('portal')
    expect(await accessGuard(route('/dashboard', { context: 'tenant' }))).toEqual({ name: 'organizations' })
  })

  it('restricts platform administration to platform admins', async () => {
    signIn([])
    expect(await accessGuard(route('/admin/tenants', { context: 'admin' }))).toEqual({ name: 'forbidden' })
    signIn([], { platform_admin: true })
    expect(await accessGuard(route('/admin/tenants', { context: 'admin' }))).toBe(true)
  })
})
