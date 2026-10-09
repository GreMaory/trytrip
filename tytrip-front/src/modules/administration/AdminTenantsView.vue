<script setup lang="ts">
import { onMounted, reactive, ref, watch } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { adminApi } from '@/api'
import { ApiError, type Pagination } from '@/api/client'
import type { AdminTenant } from '@/api/types'
import { useForm, useLoader } from '@/composables/useForm'
import { formatDate } from '@/utils/format'
import { appDomain, urlOn } from '@/utils/host'
import ErrorAlert from '@/components/ErrorAlert.vue'

const { loading, error, load } = useLoader()
const createForm = useForm()
const tenants = ref<AdminTenant[]>([])
const pagination = ref<Pagination | null>(null)
const query = ref('')
const status = ref('')
const page = ref(1)
const dialogOpen = ref(false)
const form = reactive({ name: '', subdomain: '', owner_email: '' })

async function fetch() {
  const result = await load(() => adminApi.tenants({ q: query.value || undefined, status: status.value || undefined, page: page.value }))
  if (result) {
    tenants.value = result.items
    pagination.value = result.pagination
  }
}

async function toggle(tenant: AdminTenant) {
  const suspend = tenant.status === 'active'
  try {
    await ElMessageBox.confirm(
      suspend ? `Suspendre « ${tenant.name} » ? Ses membres n’y auront plus accès.` : `Réactiver « ${tenant.name} » ?`,
      suspend ? 'Suspendre' : 'Réactiver', { type: 'warning' })
  } catch { return }
  try {
    await (suspend ? adminApi.suspendTenant(tenant.id) : adminApi.activateTenant(tenant.id))
    ElMessage.success('Organisation mise à jour')
  } catch (err) {
    ElMessage.error(err instanceof ApiError ? err.message : 'Action impossible')
  }
  fetch()
}

async function create() {
  const created = await createForm.submit(
    () => adminApi.createTenant({ name: form.name, subdomain: form.subdomain }, form.owner_email),
    'Organisation créée, invitation envoyée au propriétaire')
  if (created) {
    dialogOpen.value = false
    Object.assign(form, { name: '', subdomain: '', owner_email: '' })
    fetch()
  }
}

let timer: ReturnType<typeof setTimeout> | undefined
watch(query, () => { clearTimeout(timer); timer = setTimeout(() => { page.value = 1; fetch() }, 300) })
watch([status, page], fetch)
onMounted(fetch)
</script>

<template>
  <div class="page">
    <div class="page-header">
      <h1>Organisations</h1>
      <div class="actions"><el-button type="primary" @click="dialogOpen = true">Nouvelle organisation</el-button></div>
    </div>
    <div class="toolbar">
      <el-input v-model="query" placeholder="Nom ou sous-domaine" clearable aria-label="Rechercher" />
      <el-select v-model="status" placeholder="Statut" clearable style="width: 160px">
        <el-option label="Active" value="active" /><el-option label="Suspendue" value="suspended" />
      </el-select>
    </div>
    <ErrorAlert :message="error" />
    <el-table v-loading="loading" :data="tenants" empty-text="Aucune organisation">
      <el-table-column prop="name" label="Nom" min-width="180" />
      <el-table-column label="Adresse" min-width="200"><template #default="{ row }"><a :href="urlOn(row.subdomain)">{{ row.subdomain }}.{{ appDomain() }}</a></template></el-table-column>
      <el-table-column prop="shard" label="Shard" width="110" />
      <el-table-column prop="members_count" label="Membres" width="100" />
      <el-table-column label="Créée le" width="130"><template #default="{ row }">{{ formatDate(row.created_at) }}</template></el-table-column>
      <el-table-column label="Statut" width="120">
        <template #default="{ row }"><el-tag :type="row.status === 'active' ? 'success' : 'danger'">{{ row.status === 'active' ? 'Active' : 'Suspendue' }}</el-tag></template>
      </el-table-column>
      <el-table-column width="120">
        <template #default="{ row }"><el-button size="small" text :type="row.status === 'active' ? 'danger' : 'primary'" @click="toggle(row)">{{ row.status === 'active' ? 'Suspendre' : 'Réactiver' }}</el-button></template>
      </el-table-column>
    </el-table>
    <div class="pagination" v-if="pagination && pagination.total_pages > 1">
      <el-pagination v-model:current-page="page" :page-size="pagination.per_page" :total="pagination.total" layout="prev, pager, next" />
    </div>

    <el-dialog v-model="dialogOpen" title="Nouvelle organisation" width="480px">
      <ErrorAlert :message="createForm.error.value" />
      <el-form label-position="top" @submit.prevent="create">
        <el-form-item label="Nom" :error="createForm.fieldErrors.name" required><el-input v-model="form.name" /></el-form-item>
        <el-form-item label="Sous-domaine" :error="createForm.fieldErrors.subdomain" required>
          <el-input v-model="form.subdomain"><template #append>.{{ appDomain() }}</template></el-input>
        </el-form-item>
        <el-form-item label="Email du propriétaire (recevra une invitation)" :error="createForm.fieldErrors.email" required>
          <el-input v-model="form.owner_email" type="email" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogOpen = false">Annuler</el-button>
        <el-button type="primary" :loading="createForm.submitting.value" @click="create">Créer</el-button>
      </template>
    </el-dialog>
  </div>
</template>
