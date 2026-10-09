<script setup lang="ts">
import { computed, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import {
  Calendar, DataBoard, House, Tickets, User, Setting, UserFilled, Lock, Document, OfficeBuilding, Menu as MenuIcon, SwitchButton,
} from '@element-plus/icons-vue'
import { useAuthStore } from '@/stores/auth'
import { hostKind, urlOn } from '@/utils/host'

const auth = useAuthStore()
const route = useRoute()
const router = useRouter()
const drawerOpen = ref(false)

interface NavItem { to: string; label: string; icon: unknown; permission?: string }

const items = computed<NavItem[]>(() => {
  if (hostKind() === 'admin') {
    return [
      { to: '/admin/tenants', label: 'Organisations', icon: OfficeBuilding },
      { to: '/admin/users', label: 'Utilisateurs', icon: UserFilled },
      { to: '/admin/audit', label: 'Audit', icon: Document },
    ]
  }
  if (!auth.organization) return []
  const all: NavItem[] = [
    { to: '/dashboard', label: 'Tableau de bord', icon: DataBoard, permission: 'reservations.read' },
    { to: '/calendar', label: 'Calendrier', icon: Calendar, permission: 'reservations.read' },
    { to: '/reservations', label: 'Réservations', icon: Tickets, permission: 'reservations.read' },
    { to: '/properties', label: 'Propriétés', icon: House, permission: 'properties.read' },
    { to: '/guests', label: 'Voyageurs', icon: User, permission: 'guests.read' },
    { to: '/settings/members', label: 'Membres', icon: UserFilled, permission: 'members.read' },
    { to: '/settings/roles', label: 'Rôles', icon: Lock, permission: 'members.read' },
    { to: '/settings/organization', label: 'Organisation', icon: Setting, permission: 'organization.manage' },
    { to: '/settings/audit', label: 'Audit', icon: Document, permission: 'audit.read' },
  ]
  return all.filter((item) => !item.permission || auth.can(item.permission))
})

const activePath = computed(() => {
  const match = items.value.map((item) => item.to).filter((to) => route.path.startsWith(to)).sort((a, b) => b.length - a.length)
  return match[0] ?? route.path
})

const title = computed(() => (hostKind() === 'admin' ? 'Administration TyTrip' : auth.organization?.name ?? 'TyTrip'))

function switchOrganization(subdomain: string) {
  window.location.href = urlOn(subdomain, '/')
}

async function onUserCommand(command: string) {
  if (command === 'account') router.push({ name: 'account' })
  if (command === 'organizations') window.location.href = urlOn('app', '/organizations')
  if (command === 'admin') window.location.href = urlOn('admin', '/')
  if (command === 'logout') {
    await auth.logout()
    window.location.href = urlOn('app', '/login')
  }
}
</script>

<template>
  <el-container class="app-layout">
    <el-aside class="sidebar hidden-mobile" width="var(--tt-sidebar-width)">
      <div class="brand">TyTrip</div>
      <nav aria-label="Navigation principale">
        <el-menu :default-active="activePath" router>
          <el-menu-item v-for="item in items" :key="item.to" :index="item.to">
            <el-icon><component :is="item.icon" /></el-icon>
            <span>{{ item.label }}</span>
          </el-menu-item>
        </el-menu>
      </nav>
    </el-aside>

    <el-drawer v-model="drawerOpen" direction="ltr" size="260px" :with-header="false">
      <el-menu :default-active="activePath" router @select="drawerOpen = false">
        <el-menu-item v-for="item in items" :key="item.to" :index="item.to">
          <el-icon><component :is="item.icon" /></el-icon>
          <span>{{ item.label }}</span>
        </el-menu-item>
      </el-menu>
    </el-drawer>

    <el-container>
      <el-header class="header">
        <div class="header-left">
          <el-button class="show-mobile" :icon="MenuIcon" text aria-label="Ouvrir le menu" @click="drawerOpen = true" />
          <el-dropdown v-if="auth.me && auth.me.organizations.length > 1" trigger="click" @command="switchOrganization">
            <el-button text class="org-switcher">{{ title }} <span aria-hidden="true">▾</span></el-button>
            <template #dropdown>
              <el-dropdown-menu>
                <el-dropdown-item v-for="org in auth.me.organizations" :key="org.id" :command="org.subdomain">
                  {{ org.name }} <span class="muted">· {{ org.role }}</span>
                </el-dropdown-item>
              </el-dropdown-menu>
            </template>
          </el-dropdown>
          <strong v-else>{{ title }}</strong>
        </div>
        <el-dropdown v-if="auth.me" trigger="click" @command="onUserCommand">
          <el-button text>
            <el-icon><User /></el-icon>&nbsp;{{ auth.me.name }}
          </el-button>
          <template #dropdown>
            <el-dropdown-menu>
              <el-dropdown-item command="account" :icon="Setting">Mon compte</el-dropdown-item>
              <el-dropdown-item command="organizations" :icon="OfficeBuilding">Mes organisations</el-dropdown-item>
              <el-dropdown-item v-if="auth.me.platform_admin" command="admin" :icon="Lock">Administration plateforme</el-dropdown-item>
              <el-dropdown-item command="logout" divided :icon="SwitchButton">Se déconnecter</el-dropdown-item>
            </el-dropdown-menu>
          </template>
        </el-dropdown>
      </el-header>
      <el-alert
        v-if="auth.me && !auth.me.email_verified"
        type="warning"
        :closable="false"
        show-icon
        title="Votre adresse email n’est pas vérifiée. Consultez votre boîte de réception."
      />
      <el-main class="main">
        <slot />
      </el-main>
    </el-container>
  </el-container>
</template>

<style scoped>
.app-layout { min-height: 100vh; }
.sidebar { background: #fff; border-right: 1px solid var(--el-border-color-light); }
.sidebar .el-menu { border-right: none; }
.brand { font-size: 22px; font-weight: 700; color: var(--el-color-primary); padding: 18px 20px; }
.header { display: flex; align-items: center; justify-content: space-between; background: #fff; border-bottom: 1px solid var(--el-border-color-light); }
.header-left { display: flex; align-items: center; gap: 8px; }
.org-switcher { font-weight: 600; }
.main { padding: 0; }
.show-mobile { display: none; }
@media (max-width: 900px) {
  .hidden-mobile { display: none; }
  .show-mobile { display: inline-flex; }
}
</style>
