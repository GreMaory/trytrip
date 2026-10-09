import axios, { AxiosError, type AxiosRequestConfig } from 'axios'

/**
 * Centralized HTTP client for the Rails API.
 *
 * - Authentication relies on an HttpOnly session cookie set by the API.
 * - CSRF: the API exposes its token in the XSRF-TOKEN cookie; axios copies it
 *   into the X-CSRF-Token header of same-origin requests.
 * - Errors are normalized into ApiError ({ status, code, message, details }).
 */
export const http = axios.create({
  baseURL: '/api/v1',
  withCredentials: true,
  xsrfCookieName: 'XSRF-TOKEN',
  xsrfHeaderName: 'X-CSRF-Token',
  headers: { Accept: 'application/json' },
})

export class ApiError extends Error {
  constructor(
    public status: number,
    public code: string,
    message: string,
    public details: Record<string, string[]> = {},
  ) {
    super(message)
    this.name = 'ApiError'
  }

  get isValidation(): boolean {
    return this.code === 'validation_failed'
  }

  /** First message for a field, e.g. fieldError('email') */
  fieldError(field: string): string | undefined {
    return this.details[field]?.[0]
  }
}

type UnauthorizedHandler = () => void
let onUnauthorized: UnauthorizedHandler | null = null

/** Called when an authenticated request gets a 401 (expired or revoked session). */
export function setUnauthorizedHandler(handler: UnauthorizedHandler) {
  onUnauthorized = handler
}

interface RetriableConfig extends AxiosRequestConfig {
  _csrfRetried?: boolean
}

http.interceptors.response.use(
  (response) => response,
  async (error: AxiosError<{ error?: { code?: string; message?: string; details?: Record<string, string[]> } }>) => {
    const status = error.response?.status ?? 0
    const payload = error.response?.data?.error
    const config = error.config as RetriableConfig | undefined

    // The CSRF token rotates at sign in/out: fetch a fresh one and retry once.
    if (status === 403 && payload?.code === 'invalid_csrf_token' && config && !config._csrfRetried) {
      config._csrfRetried = true
      await http.get('/csrf')
      return http.request(config)
    }

    if (status === 401 && payload?.code === 'unauthorized' && onUnauthorized) {
      onUnauthorized()
    }

    if (!error.response) {
      return Promise.reject(new ApiError(0, 'network_error', 'Le serveur est injoignable. Vérifiez votre connexion.'))
    }
    return Promise.reject(
      new ApiError(status, payload?.code ?? 'error', payload?.message ?? 'Une erreur est survenue', payload?.details ?? {}),
    )
  },
)

/** Unwraps the { data } envelope. */
export async function get<T>(url: string, params?: Record<string, unknown>): Promise<T> {
  return (await http.get<{ data: T }>(url, { params })).data.data
}

export async function getPage<T>(url: string, params?: Record<string, unknown>): Promise<Page<T>> {
  const { data } = await http.get<{ data: T[]; meta: { pagination: Pagination } }>(url, { params })
  return { items: data.data, pagination: data.meta.pagination }
}

export async function post<T = void>(url: string, body?: unknown): Promise<T> {
  return (await http.post<{ data: T }>(url, body)).data?.data as T
}

export async function patch<T = void>(url: string, body?: unknown): Promise<T> {
  return (await http.patch<{ data: T }>(url, body)).data?.data as T
}

export async function del(url: string, body?: unknown): Promise<void> {
  await http.delete(url, { data: body })
}

export interface Pagination {
  page: number
  per_page: number
  total: number
  total_pages: number
}

export interface Page<T> {
  items: T[]
  pagination: Pagination
}
