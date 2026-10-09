// Shapes returned by the Rails API (see tytrip-back/app/views/api/v1).

export type ISODate = string // "2027-07-10"
export type ISODateTime = string
export type Money = string // decimal as string, e.g. "1000.0"

export interface UserSummary {
  id: number
  name: string
  email: string
}

export interface Organization {
  id: number
  name: string
  subdomain: string
  status: 'active' | 'suspended'
  time_zone: string
  locale: string
  currency: string
  host: string
  created_at: ISODateTime
}

export interface Me {
  id: number
  name: string
  email: string
  locale: string
  time_zone: string
  preferences: Record<string, unknown>
  last_sign_in_at: ISODateTime | null
  email_verified: boolean
  mfa_enabled: boolean
  platform_admin: boolean
  organizations: Array<{ id: number; name: string; subdomain: string; host: string; role: string }>
  current_organization:
    | (Organization & { membership_id: number; role: { id: number; key: string | null; name: string }; permissions: string[] })
    | null
}

export interface Role {
  id: number
  key: string | null
  name: string
  description: string | null
  system: boolean
  permissions: string[]
  members_count?: number
}

export interface Permission {
  key: string
  description: string
}

export interface Membership {
  id: number
  status: 'active' | 'suspended'
  created_at: ISODateTime
  user: UserSummary
  role: { id: number; key: string | null; name: string }
}

export interface Invitation {
  id: number
  email: string
  expires_at: ISODateTime
  created_at: ISODateTime
  role: { id: number; name: string }
  invited_by: UserSummary
}

export interface AuditEvent {
  id: number
  action: string
  subject_type: string | null
  subject_id: number | null
  metadata: Record<string, unknown>
  ip_address: string | null
  tenant_id: number | null
  created_at: ISODateTime
  actor: UserSummary | null
}

export interface DeviceSession {
  id: number
  ip_address: string | null
  user_agent: string | null
  created_at: ISODateTime
  last_seen_at: ISODateTime | null
  expires_at: ISODateTime
  current: boolean
}

export interface Unit {
  id: number
  property_id: number
  name: string
  status: 'active' | 'inactive'
  max_guests: number
  bedrooms: number
  beds: number
  bathrooms: string
  base_rate: Money
  min_stay: number
  max_stay: number | null
  property_name?: string
}

export interface Property {
  id: number
  name: string
  property_type: string
  status: 'active' | 'archived'
  description: string | null
  address_line1: string | null
  address_line2: string | null
  postal_code: string | null
  city: string | null
  country_code: string | null
  latitude: string | null
  longitude: string | null
  time_zone: string
  check_in_time: string
  check_out_time: string
  house_rules: string | null
  access_instructions: string | null
  amenities: string[]
  units: Unit[]
  created_at: ISODateTime
  updated_at: ISODateTime
}

export interface Guest {
  id: number
  first_name: string
  last_name: string
  full_name: string
  email: string | null
  phone: string | null
  country_code: string | null
  language: string | null
  notes: string | null
  marketing_consent: boolean
  marketing_consent_at: ISODateTime | null
  created_at: ISODateTime
  reservations?: Array<{
    id: number
    reference: string
    status: ReservationStatus
    check_in: ISODate
    check_out: ISODate
    total_amount: Money
    currency: string
    unit_name: string
    property_name: string
  }>
}

export type ReservationStatus = 'pending' | 'confirmed' | 'checked_in' | 'checked_out' | 'cancelled' | 'no_show'
export type ReservationEvent = 'confirm' | 'check_in' | 'check_out' | 'cancel' | 'mark_no_show'

export interface Reservation {
  id: number
  reference: string
  status: ReservationStatus
  source: string
  check_in: ISODate
  check_out: ISODate
  nights: number
  adults: number
  children: number
  currency: string
  nightly_rate: Money
  total_amount: Money
  notes: string | null
  special_requests: string | null
  confirmed_at: ISODateTime | null
  checked_in_at: ISODateTime | null
  checked_out_at: ISODateTime | null
  cancelled_at: ISODateTime | null
  cancellation_reason: string | null
  created_at: ISODateTime
  updated_at: ISODateTime
  available_events: ReservationEvent[]
  unit: { id: number; name: string; property: { id: number; name: string } }
  guest: Guest
}

export interface AvailabilityBlock {
  id: number
  unit_id: number
  starts_on: ISODate
  ends_on: ISODate
  reason: string
  note: string | null
}

export interface CalendarData {
  from: ISODate
  to: ISODate
  units: Array<{
    id: number
    name: string
    max_guests: number
    property: { id: number; name: string }
    reservations: Array<{
      id: number
      reference: string
      status: ReservationStatus
      check_in: ISODate
      check_out: ISODate
      adults: number
      children: number
      guest_name: string
    }>
    blocks: AvailabilityBlock[]
  }>
}

export interface DashboardMovement {
  id: number
  reference: string
  status: ReservationStatus
  guest_name: string
  unit_name: string
  property_name: string
  check_in: ISODate
  check_out: ISODate
}

export interface Dashboard {
  date: ISODate
  arrivals: DashboardMovement[]
  departures: DashboardMovement[]
  in_house_count: number
  pending_count: number
  occupancy_rate: number
  revenue_month: { amount: Money; currency: string }
  units_count: number
}

export interface AdminTenant extends Organization {
  shard: string
  suspended_at: ISODateTime | null
  members_count: number
}

export interface AdminUser {
  id: number
  name: string
  email: string
  status: 'active' | 'suspended'
  platform_role: string | null
  last_sign_in_at: ISODateTime | null
  created_at: ISODateTime
  email_verified: boolean
  mfa_enabled: boolean
  locked: boolean
  memberships?: Array<{ id: number; status: string; organization: { id: number; name: string; subdomain: string }; role: string }>
}
