import { defineStore } from 'pinia'
import { computed, ref } from 'vue'
import { authApi } from '@/api'
import { ApiError } from '@/api/client'
import type { Me } from '@/api/types'

/**
 * Signed-in user and their permissions in the current organization.
 * Permissions only drive the UI (hiding actions); the API enforces them.
 */
export const useAuthStore = defineStore('auth', () => {
  const me = ref<Me | null>(null)
  const loaded = ref(false)
  const sessionExpired = ref(false)

  const isAuthenticated = computed(() => me.value !== null)
  const organization = computed(() => me.value?.current_organization ?? null)
  const permissions = computed(() => new Set(organization.value?.permissions ?? []))

  function can(permission: string): boolean {
    return permissions.value.has(permission)
  }

  async function fetchMe(): Promise<Me | null> {
    try {
      me.value = await authApi.me()
    } catch (error) {
      if (!(error instanceof ApiError) || error.status !== 401) throw error
      me.value = null
    } finally {
      loaded.value = true
    }
    return me.value
  }

  /** Returns true when a second factor is required. */
  async function login(email: string, password: string): Promise<boolean> {
    await authApi.csrf()
    const { mfa_required } = await authApi.login(email, password)
    if (!mfa_required) await afterSignIn()
    return mfa_required
  }

  async function verifyMfa(code: string) {
    await authApi.verifyMfa(code)
    await afterSignIn()
  }

  async function afterSignIn() {
    sessionExpired.value = false
    await fetchMe()
  }

  async function logout() {
    try {
      await authApi.logout()
    } finally {
      me.value = null
    }
  }

  /** Called by the HTTP client on 401 for an authenticated user. */
  function markSessionExpired() {
    if (me.value) sessionExpired.value = true
    me.value = null
  }

  return { me, loaded, sessionExpired, isAuthenticated, organization, can, fetchMe, login, verifyMfa, logout, markSessionExpired }
})
