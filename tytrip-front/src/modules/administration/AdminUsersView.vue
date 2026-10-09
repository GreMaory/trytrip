<script setup lang="ts">
import { onMounted, ref, watch } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { adminApi } from '@/api'
import { ApiError, type Pagination } from '@/api/client'
import type { AdminUser } from '@/api/types'
import { useLoader } from '@/composables/useForm'
import { formatDateTime } from '@/utils/format'
import ErrorAlert from '@/components/ErrorAlert.vue'

const { loading, error, load } = useLoader()
const users = ref<AdminUser[]>([])
const pagination = ref<Pagination | null>(null)
const query = ref('')
const page = ref(1)
const selected = ref<AdminUser | null>(null)

async function fetch() {
  const result = await load(() => adminApi.users({ q: query.value || undefined, page: page.value }))
  if (result) {
    users.value = result.items
    pagination.value = result.pagination
  }
}

async function show(user: AdminUser) {
  selected.value = await adminApi.user(user.id)
}

async function act(label: string, action: () => Promise<unknown>) {
  try {
    await ElMessageBox.confirm(`${label} ?`, 'Confirmation', { type: 'warning' })
  } catch { return }
  try {
    await action()
    ElMessage.success('Action effectuée')
    if (selected.value) selected.value = await adminApi.user(selected.value.id)
  } catch (err) {
    ElMessage.error(err instanceof ApiError ? err.message : 'Action impossible')
  }
  fetch()
}

const suspend = (user: AdminUser) => act('Suspendre cet utilisateur', () => adminApi.suspendUser(user.id))
const activate = (user: AdminUser) => act('Réactiver cet utilisateur', () => adminApi.activateUser(user.id))
const revokeSessions = (user: AdminUser) => act('Déconnecter toutes ses sessions', () => adminApi.revokeUserSessions(user.id))

let timer: ReturnType<typeof setTimeout> | undefined
watch(query, () => { clearTimeout(timer); timer = setTimeout(() => { page.value = 1; fetch() }, 300) })
watch(page, fetch)
onMounted(fetch)
</script>

<template>
  <div class="page">
    <div class="page-header"><h1>Utilisateurs</h1></div>
    <div class="toolbar"><el-input v-model="query" placeholder="Nom ou email" clearable aria-label="Rechercher" /></div>
    <ErrorAlert :message="error" />
    <el-table v-loading="loading" :data="users" @row-click="show" style="cursor: pointer">
      <el-table-column prop="name" label="Nom" min-width="160" />
      <el-table-column prop="email" label="Email" min-width="200" />
      <el-table-column label="Sécurité" width="200">
        <template #default="{ row }">
          <el-tag v-if="row.mfa_enabled" size="small" type="success">2FA</el-tag>
          <el-tag v-if="!row.email_verified" size="small" type="warning">Email non vérifié</el-tag>
          <el-tag v-if="row.locked" size="small" type="danger">Verrouillé</el-tag>
          <el-tag v-if="row.platform_role" size="small">Admin plateforme</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="Dernière connexion" width="170"><template #default="{ row }">{{ formatDateTime(row.last_sign_in_at) }}</template></el-table-column>
      <el-table-column label="Statut" width="110">
        <template #default="{ row }"><el-tag :type="row.status === 'active' ? 'success' : 'danger'">{{ row.status === 'active' ? 'Actif' : 'Suspendu' }}</el-tag></template>
      </el-table-column>
    </el-table>
    <div class="pagination" v-if="pagination && pagination.total_pages > 1">
      <el-pagination v-model:current-page="page" :page-size="pagination.per_page" :total="pagination.total" layout="prev, pager, next" />
    </div>

    <el-drawer :model-value="!!selected" :title="selected?.name" size="420px" @close="selected = null">
      <template v-if="selected">
        <p>{{ selected.email }}</p>
        <h3>Organisations</h3>
        <el-empty v-if="!selected.memberships?.length" :image-size="50" description="Aucune" />
        <ul><li v-for="m in selected.memberships" :key="m.id">{{ m.organization.name }} — {{ m.role }} <span class="muted">({{ m.status }})</span></li></ul>
        <div class="drawer-actions">
          <el-button v-if="selected.status === 'active'" type="danger" plain @click="suspend(selected)">Suspendre</el-button>
          <el-button v-else type="primary" @click="activate(selected)">Réactiver / déverrouiller</el-button>
          <el-button @click="revokeSessions(selected)">Révoquer les sessions</el-button>
        </div>
      </template>
    </el-drawer>
  </div>
</template>

<style scoped>
.drawer-actions { display: flex; gap: 8px; flex-wrap: wrap; margin-top: 24px; }
h3 { font-size: 14px; }
.el-tag + .el-tag { margin-left: 4px; }
</style>
