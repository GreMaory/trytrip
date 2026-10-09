import { beforeEach, describe, expect, it, vi } from 'vitest'
import { flushPromises, mount } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'
import { createMemoryHistory, createRouter } from 'vue-router'
import ElementPlus from 'element-plus'
import LoginView from '@/modules/auth/LoginView.vue'
import { useAuthStore } from '@/stores/auth'
import { ApiError } from '@/api/client'

async function mountLogin(redirect?: string) {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: '/', component: { template: '<div />' } },
      { path: '/login', component: LoginView },
      { path: '/reservations', component: { template: '<div />' } },
    ],
  })
  router.push(redirect ? { path: '/login', query: { redirect } } : '/login')
  await router.isReady()
  const wrapper = mount(LoginView, { global: { plugins: [router, ElementPlus] } })
  return { wrapper, router }
}

async function fillAndSubmit(wrapper: Awaited<ReturnType<typeof mountLogin>>['wrapper']) {
  await wrapper.find('input[type="email"]').setValue('jane@example.com')
  await wrapper.find('input[type="password"]').setValue('secret-password')
  await wrapper.find('form').trigger('submit')
  await flushPromises()
}

describe('LoginView', () => {
  beforeEach(() => setActivePinia(createPinia()))

  it('signs in and follows a safe redirect', async () => {
    const auth = useAuthStore()
    auth.login = vi.fn().mockResolvedValue(false)
    const { wrapper, router } = await mountLogin('/reservations')
    await fillAndSubmit(wrapper)
    expect(auth.login).toHaveBeenCalledWith('jane@example.com', 'secret-password')
    expect(router.currentRoute.value.path).toBe('/reservations')
  })

  it('ignores redirects to other sites', async () => {
    useAuthStore().login = vi.fn().mockResolvedValue(false)
    const { wrapper, router } = await mountLogin('//evil.example.com')
    await fillAndSubmit(wrapper)
    expect(router.currentRoute.value.path).toBe('/')
  })

  it('asks for the second factor when required', async () => {
    const auth = useAuthStore()
    auth.login = vi.fn().mockResolvedValue(true)
    auth.verifyMfa = vi.fn().mockResolvedValue(undefined)
    const { wrapper, router } = await mountLogin()
    await fillAndSubmit(wrapper)
    expect(wrapper.text()).toContain('Code de vérification')
    expect(router.currentRoute.value.path).toBe('/login')

    await wrapper.find('input[autocomplete="one-time-code"]').setValue('123456')
    await wrapper.find('form').trigger('submit')
    await flushPromises()
    expect(auth.verifyMfa).toHaveBeenCalledWith('123456')
    expect(router.currentRoute.value.path).toBe('/')
  })

  it('shows the error returned by the API', async () => {
    useAuthStore().login = vi.fn().mockRejectedValue(new ApiError(401, 'invalid_credentials', 'Invalid email or password'))
    const { wrapper } = await mountLogin()
    await fillAndSubmit(wrapper)
    expect(wrapper.find('[role="alert"]').text()).toContain('Invalid email or password')
  })
})
