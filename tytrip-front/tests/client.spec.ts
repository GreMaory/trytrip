import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import type { AxiosAdapter, InternalAxiosRequestConfig } from 'axios'
import { ApiError, get, http, post, setUnauthorizedHandler } from '@/api/client'

function respond(status: number, data: unknown, config: InternalAxiosRequestConfig) {
  const response = { status, data, headers: {}, config, statusText: '' }
  if (status >= 400) {
    const error = Object.assign(new Error(`HTTP ${status}`), { isAxiosError: true, response, config })
    return Promise.reject(error)
  }
  return Promise.resolve(response)
}

describe('api client', () => {
  const originalAdapter = http.defaults.adapter
  let calls: string[]

  beforeEach(() => { calls = [] })
  afterEach(() => { http.defaults.adapter = originalAdapter })

  function useAdapter(handler: (config: InternalAxiosRequestConfig) => Promise<unknown>) {
    http.defaults.adapter = ((config: InternalAxiosRequestConfig) => {
      calls.push(`${config.method?.toUpperCase()} ${config.url}`)
      return handler(config)
    }) as AxiosAdapter
  }

  it('unwraps the data envelope', async () => {
    useAdapter((config) => respond(200, { data: { id: 1 } }, config))
    expect(await get('/me')).toEqual({ id: 1 })
  })

  it('normalizes validation errors', async () => {
    useAdapter((config) =>
      respond(422, { error: { code: 'validation_failed', message: 'Validation failed', details: { email: ['is invalid'] } } }, config))
    const error = await post('/signup', {}).catch((e) => e)
    expect(error).toBeInstanceOf(ApiError)
    expect(error.status).toBe(422)
    expect(error.isValidation).toBe(true)
    expect(error.fieldError('email')).toBe('is invalid')
  })

  it('refreshes the CSRF token and retries once', async () => {
    let attempts = 0
    useAdapter((config) => {
      if (config.url === '/csrf') return respond(204, '', config)
      attempts += 1
      return attempts === 1
        ? respond(403, { error: { code: 'invalid_csrf_token', message: 'Invalid CSRF token' } }, config)
        : respond(200, { data: { ok: true } }, config)
    })
    expect(await post('/session', {})).toEqual({ ok: true })
    expect(calls).toEqual(['POST /session', 'GET /csrf', 'POST /session'])
  })

  it('notifies the application when the session has expired', async () => {
    const handler = vi.fn()
    setUnauthorizedHandler(handler)
    useAdapter((config) => respond(401, { error: { code: 'unauthorized', message: 'Authentication required' } }, config))
    await expect(get('/reservations')).rejects.toBeInstanceOf(ApiError)
    expect(handler).toHaveBeenCalledOnce()
  })

  it('does not treat bad credentials as an expired session', async () => {
    const handler = vi.fn()
    setUnauthorizedHandler(handler)
    useAdapter((config) => respond(401, { error: { code: 'invalid_credentials', message: 'Invalid email or password' } }, config))
    await expect(post('/session', {})).rejects.toMatchObject({ code: 'invalid_credentials' })
    expect(handler).not.toHaveBeenCalled()
  })
})
