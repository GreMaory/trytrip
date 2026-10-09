import { del, get, getPage, http, patch, post } from './client'
import type {
  AdminTenant, AdminUser, AuditEvent, AvailabilityBlock, CalendarData, Dashboard, DeviceSession, Guest, Invitation,
  Me, Membership, Organization, Permission, Property, Reservation, ReservationEvent, Role, Unit,
} from './types'

type Params = Record<string, unknown>

export const authApi = {
  csrf: () => http.get('/csrf'),
  me: () => get<Me>('/me'),
  updateMe: (user: Partial<Pick<Me, 'name' | 'locale' | 'time_zone'>>) => patch('/me', { user }),
  login: (email: string, password: string) => post<{ mfa_required: boolean }>('/session', { email, password }),
  verifyMfa: (code: string) => post<{ mfa_required: boolean }>('/session/mfa', { code }),
  logout: () => del('/session'),
  signup: (body: { user: { name: string; email: string; password: string }; organization: { name: string; subdomain: string } }) =>
    post<{ organization: { id: number; name: string; subdomain: string; host: string } }>('/signup', body),
  requestPasswordReset: (email: string) => post('/password_reset', { email }),
  resetPassword: (token: string, password: string) => patch('/password_reset', { token, password }),
  resendVerification: () => post('/email_verification'),
  verifyEmail: (token: string) => patch('/email_verification', { token }),
  changePassword: (current_password: string, password: string) => patch('/me/password', { current_password, password }),
  sessions: () => get<DeviceSession[]>('/me/sessions'),
  revokeSession: (id: number) => del(`/me/sessions/${id}`),
  revokeOtherSessions: () => del('/me/sessions/others'),
  startMfa: () => post<{ secret: string; provisioning_uri: string }>('/me/mfa'),
  enableMfa: (code: string) => patch<{ recovery_codes: string[] }>('/me/mfa', { code }),
  disableMfa: (password: string, code: string) => del('/me/mfa', { password, code }),
  regenerateRecoveryCodes: (code: string) => post<{ recovery_codes: string[] }>('/me/mfa/recovery_codes', { code }),
}

export const invitationAcceptanceApi = {
  show: (token: string) =>
    get<{ email: string; organization: { name: string; subdomain: string }; role: string; existing_account: boolean; expires_at: string }>(
      '/invitation_acceptance', { token }),
  accept: (body: { token: string; name?: string; password: string }) =>
    post<{ organization: { subdomain: string }; signed_in: boolean }>('/invitation_acceptance', body),
}

export const organizationApi = {
  show: () => get<Organization>('/organization'),
  update: (organization: Partial<Organization>) => patch<Organization>('/organization', { organization }),
  create: (organization: { name: string; subdomain: string }) => post<Organization>('/organizations', { organization }),
  memberships: (params?: Params) => getPage<Membership>('/memberships', params),
  updateMembership: (id: number, membership: { role_id?: number; status?: string }) =>
    patch<Membership>(`/memberships/${id}`, { membership }),
  removeMembership: (id: number) => del(`/memberships/${id}`),
  roles: () => get<Role[]>('/roles'),
  createRole: (role: Partial<Role>) => post<Role>('/roles', { role }),
  updateRole: (id: number, role: Partial<Role>) => patch<Role>(`/roles/${id}`, { role }),
  deleteRole: (id: number) => del(`/roles/${id}`),
  permissions: () => get<Permission[]>('/permissions'),
  invitations: () => get<Invitation[]>('/invitations'),
  invite: (invitation: { email: string; role_id: number }) => post<Invitation>('/invitations', { invitation }),
  revokeInvitation: (id: number) => del(`/invitations/${id}`),
  auditEvents: (params?: Params) => getPage<AuditEvent>('/audit_events', params),
}

export const pmsApi = {
  dashboard: () => get<Dashboard>('/dashboard'),
  calendar: (params: { from: string; to: string; property_id?: number }) => get<CalendarData>('/calendar', params),
  properties: (params?: Params) => getPage<Property>('/properties', params),
  property: (id: number) => get<Property>(`/properties/${id}`),
  createProperty: (property: Partial<Property>, unit?: Partial<Unit>) => post<Property>('/properties', { property, unit }),
  updateProperty: (id: number, property: Partial<Property>) => patch<Property>(`/properties/${id}`, { property }),
  archiveProperty: (id: number) => del(`/properties/${id}`),
  units: (params?: Params) => get<Unit[]>('/units', params),
  createUnit: (property_id: number, unit: Partial<Unit>) => post<Unit>('/units', { property_id, unit }),
  updateUnit: (id: number, unit: Partial<Unit>) => patch<Unit>(`/units/${id}`, { unit }),
  removeUnit: (id: number) => del(`/units/${id}`),
  guests: (params?: Params) => getPage<Guest>('/guests', params),
  guest: (id: number) => get<Guest>(`/guests/${id}`),
  createGuest: (guest: Partial<Guest>) => post<Guest>('/guests', { guest }),
  updateGuest: (id: number, guest: Partial<Guest>) => patch<Guest>(`/guests/${id}`, { guest }),
  deleteGuest: (id: number) => del(`/guests/${id}`),
  reservations: (params?: Params) => getPage<Reservation>('/reservations', params),
  reservation: (id: number) => get<Reservation>(`/reservations/${id}`),
  createReservation: (reservation: Record<string, unknown>, guest?: Partial<Guest>) =>
    post<Reservation>('/reservations', { reservation, guest }),
  updateReservation: (id: number, reservation: Record<string, unknown>) => patch<Reservation>(`/reservations/${id}`, { reservation }),
  transitionReservation: (id: number, event: ReservationEvent, reason?: string) =>
    post<Reservation>(`/reservations/${id}/transition`, { event, reason }),
  createBlock: (availability_block: Omit<AvailabilityBlock, 'id' | 'note'> & { note?: string }) =>
    post<AvailabilityBlock>('/availability_blocks', { availability_block }),
  deleteBlock: (id: number) => del(`/availability_blocks/${id}`),
}

export const adminApi = {
  tenants: (params?: Params) => getPage<AdminTenant>('/admin/tenants', params),
  createTenant: (organization: { name: string; subdomain: string }, owner_email: string) =>
    post<AdminTenant>('/admin/tenants', { organization, owner_email }),
  suspendTenant: (id: number) => post<AdminTenant>(`/admin/tenants/${id}/suspend`),
  activateTenant: (id: number) => post<AdminTenant>(`/admin/tenants/${id}/activate`),
  users: (params?: Params) => getPage<AdminUser>('/admin/users', params),
  user: (id: number) => get<AdminUser>(`/admin/users/${id}`),
  suspendUser: (id: number) => post<AdminUser>(`/admin/users/${id}/suspend`),
  activateUser: (id: number) => post<AdminUser>(`/admin/users/${id}/activate`),
  revokeUserSessions: (id: number) => post(`/admin/users/${id}/revoke_sessions`),
  auditEvents: (params?: Params) => getPage<AuditEvent>('/admin/audit_events', params),
}
