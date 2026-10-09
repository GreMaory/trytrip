/**
 * The SPA runs on several hosts:
 *   <tenant>.<domain>  organization back-office
 *   app.<domain>       portal (sign in, sign up, organization choice)
 *   admin.<domain>     platform administration
 */
export type HostKind = 'tenant' | 'portal' | 'admin'

const RESERVED = ['app', 'admin', 'www', 'api', 'mail', 'static', 'assets']

export function appDomain(): string {
  return import.meta.env.VITE_APP_DOMAIN || 'lvh.me'
}

export function currentSubdomain(hostname = window.location.hostname): string | null {
  const domain = appDomain()
  if (!hostname.endsWith(`.${domain}`)) return null
  return hostname.slice(0, -(domain.length + 1)) || null
}

export function hostKind(hostname = window.location.hostname): HostKind {
  const subdomain = currentSubdomain(hostname)
  if (subdomain === 'admin') return 'admin'
  if (!subdomain || RESERVED.includes(subdomain)) return 'portal'
  return 'tenant'
}

/** Absolute URL of a path on another subdomain, keeping protocol and port. */
export function urlOn(subdomain: string, path = '/'): string {
  const { protocol, port } = window.location
  return `${protocol}//${subdomain}.${appDomain()}${port ? `:${port}` : ''}${path}`
}
