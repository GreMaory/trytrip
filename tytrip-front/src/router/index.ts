import { createRouter, createWebHistory, type RouteLocationNormalized, type RouteRecordRaw } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { hostKind } from '@/utils/host'

declare module 'vue-router' {
  interface RouteMeta {
    /** Reachable without being signed in */
    public?: boolean
    /** Public page that signed-in users are redirected away from (login...) */
    guestOnly?: boolean
    layout?: 'auth' | 'app'
    /** tenant: needs an organization subdomain and a membership; admin: platform admins */
    context?: 'tenant' | 'admin'
    /** UI-side permission check (the API enforces it anyway) */
    permission?: string
    title?: string
  }
}

const routes: RouteRecordRaw[] = [
  {
    path: '/',
    name: 'home',
    redirect: () => {
      const kind = hostKind()
      if (kind === 'tenant') return { name: 'dashboard' }
      if (kind === 'admin') return { name: 'admin-tenants' }
      return { name: 'organizations' }
    },
  },

  // --- Authentication (portal) ---
  { path: '/login', name: 'login', component: () => import('@/modules/auth/LoginView.vue'), meta: { public: true, guestOnly: true, layout: 'auth', title: 'Connexion' } },
  { path: '/signup', name: 'signup', component: () => import('@/modules/auth/SignupView.vue'), meta: { public: true, guestOnly: true, layout: 'auth', title: 'Créer un compte' } },
  { path: '/forgot-password', name: 'forgot-password', component: () => import('@/modules/auth/ForgotPasswordView.vue'), meta: { public: true, layout: 'auth', title: 'Mot de passe oublié' } },
  { path: '/reset-password', name: 'reset-password', component: () => import('@/modules/auth/ResetPasswordView.vue'), meta: { public: true, layout: 'auth', title: 'Nouveau mot de passe' } },
  { path: '/verify-email', name: 'verify-email', component: () => import('@/modules/auth/VerifyEmailView.vue'), meta: { public: true, layout: 'auth', title: 'Vérification de l’email' } },
  { path: '/invitations/accept', name: 'accept-invitation', component: () => import('@/modules/auth/AcceptInvitationView.vue'), meta: { public: true, layout: 'auth', title: 'Invitation' } },
  { path: '/organizations', name: 'organizations', component: () => import('@/modules/auth/OrganizationsView.vue'), meta: { layout: 'auth', title: 'Mes organisations' } },

  // --- Account (any host) ---
  { path: '/account', name: 'account', component: () => import('@/modules/settings/AccountView.vue'), meta: { title: 'Mon compte' } },

  // --- Organization back-office ---
  { path: '/dashboard', name: 'dashboard', component: () => import('@/modules/dashboard/DashboardView.vue'), meta: { context: 'tenant', permission: 'reservations.read', title: 'Tableau de bord' } },
  { path: '/calendar', name: 'calendar', component: () => import('@/modules/reservations/CalendarView.vue'), meta: { context: 'tenant', permission: 'reservations.read', title: 'Calendrier' } },
  { path: '/reservations', name: 'reservations', component: () => import('@/modules/reservations/ReservationsView.vue'), meta: { context: 'tenant', permission: 'reservations.read', title: 'Réservations' } },
  { path: '/reservations/new', name: 'reservation-new', component: () => import('@/modules/reservations/ReservationFormView.vue'), meta: { context: 'tenant', permission: 'reservations.manage', title: 'Nouvelle réservation' } },
  { path: '/reservations/:id', name: 'reservation', component: () => import('@/modules/reservations/ReservationView.vue'), props: true, meta: { context: 'tenant', permission: 'reservations.read', title: 'Réservation' } },
  { path: '/reservations/:id/edit', name: 'reservation-edit', component: () => import('@/modules/reservations/ReservationFormView.vue'), props: true, meta: { context: 'tenant', permission: 'reservations.manage', title: 'Modifier la réservation' } },
  { path: '/properties', name: 'properties', component: () => import('@/modules/properties/PropertiesView.vue'), meta: { context: 'tenant', permission: 'properties.read', title: 'Propriétés' } },
  { path: '/properties/new', name: 'property-new', component: () => import('@/modules/properties/PropertyFormView.vue'), meta: { context: 'tenant', permission: 'properties.manage', title: 'Nouvelle propriété' } },
  { path: '/properties/:id', name: 'property', component: () => import('@/modules/properties/PropertyView.vue'), props: true, meta: { context: 'tenant', permission: 'properties.read', title: 'Propriété' } },
  { path: '/properties/:id/edit', name: 'property-edit', component: () => import('@/modules/properties/PropertyFormView.vue'), props: true, meta: { context: 'tenant', permission: 'properties.manage', title: 'Modifier la propriété' } },
  { path: '/guests', name: 'guests', component: () => import('@/modules/guests/GuestsView.vue'), meta: { context: 'tenant', permission: 'guests.read', title: 'Voyageurs' } },
  { path: '/guests/:id', name: 'guest', component: () => import('@/modules/guests/GuestView.vue'), props: true, meta: { context: 'tenant', permission: 'guests.read', title: 'Voyageur' } },
  { path: '/settings/organization', name: 'settings-organization', component: () => import('@/modules/settings/OrganizationSettingsView.vue'), meta: { context: 'tenant', permission: 'organization.manage', title: 'Organisation' } },
  { path: '/settings/members', name: 'settings-members', component: () => import('@/modules/settings/MembersView.vue'), meta: { context: 'tenant', permission: 'members.read', title: 'Membres' } },
  { path: '/settings/roles', name: 'settings-roles', component: () => import('@/modules/settings/RolesView.vue'), meta: { context: 'tenant', permission: 'members.read', title: 'Rôles et permissions' } },
  { path: '/settings/audit', name: 'settings-audit', component: () => import('@/modules/settings/AuditView.vue'), meta: { context: 'tenant', permission: 'audit.read', title: 'Journal d’audit' } },

  // --- Platform administration ---
  { path: '/admin/tenants', name: 'admin-tenants', component: () => import('@/modules/administration/AdminTenantsView.vue'), meta: { context: 'admin', title: 'Organisations' } },
  { path: '/admin/users', name: 'admin-users', component: () => import('@/modules/administration/AdminUsersView.vue'), meta: { context: 'admin', title: 'Utilisateurs' } },
  { path: '/admin/audit', name: 'admin-audit', component: () => import('@/modules/administration/AdminAuditView.vue'), meta: { context: 'admin', title: 'Audit plateforme' } },

  { path: '/forbidden', name: 'forbidden', component: () => import('@/components/ForbiddenView.vue'), meta: { title: 'Accès refusé' } },
  { path: '/:pathMatch(.*)*', name: 'not-found', component: () => import('@/components/NotFoundView.vue'), meta: { public: true, title: 'Page introuvable' } },
]

/** Navigation guard: user experience only, the API is the real authority. */
export async function accessGuard(to: RouteLocationNormalized) {
  const auth = useAuthStore()
  if (!auth.loaded) await auth.fetchMe().catch(() => null)

  if (to.meta.public) {
    return to.meta.guestOnly && auth.isAuthenticated ? { name: 'home' } : true
  }
  if (!auth.isAuthenticated) {
    return { name: 'login', query: to.fullPath !== '/' ? { redirect: to.fullPath } : {} }
  }
  if (to.meta.context === 'tenant' && (hostKind() !== 'tenant' || !auth.organization)) {
    return { name: 'organizations' }
  }
  if (to.meta.context === 'admin' && !auth.me?.platform_admin) {
    return { name: 'forbidden' }
  }
  if (to.meta.permission && !auth.can(to.meta.permission)) {
    return { name: 'forbidden' }
  }
  return true
}

export function createAppRouter() {
  const router = createRouter({ history: createWebHistory(), routes })
  router.beforeEach(accessGuard)
  router.afterEach((to) => {
    document.title = to.meta.title ? `${to.meta.title} · TyTrip` : 'TyTrip'
  })
  return router
}
