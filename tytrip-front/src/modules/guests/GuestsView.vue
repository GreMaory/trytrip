<script setup lang="ts">
import { onMounted, reactive, ref, watch } from 'vue'
import { pmsApi } from '@/api'
import type { Pagination } from '@/api/client'
import type { Guest } from '@/api/types'
import { useForm, useLoader } from '@/composables/useForm'
import { useAuthStore } from '@/stores/auth'
import ErrorAlert from '@/components/ErrorAlert.vue'

const auth = useAuthStore()
const { loading, error, load } = useLoader()
const createForm = useForm()
const guests = ref<Guest[]>([])
const pagination = ref<Pagination | null>(null)
const query = ref('')
const page = ref(1)
const dialogOpen = ref(false)
const guest = reactive({ first_name: '', last_name: '', email: '', phone: '', country_code: '', marketing_consent: false })

async function fetch() {
  const result = await load(() => pmsApi.guests({ q: query.value || undefined, page: page.value }))
  if (result) {
    guests.value = result.items
    pagination.value = result.pagination
  }
}

async function create() {
  const created = await createForm.submit(() => pmsApi.createGuest({ ...guest, country_code: guest.country_code || null }), 'Voyageur créé')
  if (created) {
    dialogOpen.value = false
    fetch()
  }
}

let timer: ReturnType<typeof setTimeout> | undefined
watch(query, () => { clearTimeout(timer); timer = setTimeout(() => { page.value = 1; fetch() }, 300) })
watch(page, fetch)
onMounted(fetch)
</script>

<template>
  <div class="page">
    <div class="page-header">
      <h1>Voyageurs</h1>
      <div class="actions"><el-button v-if="auth.can('guests.manage')" type="primary" @click="dialogOpen = true">Nouveau voyageur</el-button></div>
    </div>
    <div class="toolbar"><el-input v-model="query" placeholder="Nom, email, téléphone…" clearable aria-label="Rechercher" /></div>
    <ErrorAlert :message="error" />
    <el-table v-loading="loading" :data="guests" empty-text="Aucun voyageur" @row-click="(row: Guest) => $router.push(`/guests/${row.id}`)" style="cursor: pointer">
      <el-table-column prop="full_name" label="Nom" min-width="180" />
      <el-table-column label="Email" min-width="200"><template #default="{ row }">{{ row.email ?? '—' }}</template></el-table-column>
      <el-table-column label="Téléphone" width="160"><template #default="{ row }">{{ row.phone ?? '—' }}</template></el-table-column>
      <el-table-column label="Pays" width="80"><template #default="{ row }">{{ row.country_code ?? '—' }}</template></el-table-column>
      <el-table-column label="Marketing" width="110"><template #default="{ row }">{{ row.marketing_consent ? 'Oui' : 'Non' }}</template></el-table-column>
    </el-table>
    <div class="pagination" v-if="pagination && pagination.total_pages > 1">
      <el-pagination v-model:current-page="page" :page-size="pagination.per_page" :total="pagination.total" layout="prev, pager, next" />
    </div>

    <el-dialog v-model="dialogOpen" title="Nouveau voyageur" width="520px">
      <ErrorAlert :message="createForm.error.value" />
      <el-form label-position="top" @submit.prevent="create">
        <div class="grid grid-2">
          <el-form-item label="Prénom" :error="createForm.fieldErrors.first_name" required><el-input v-model="guest.first_name" /></el-form-item>
          <el-form-item label="Nom" :error="createForm.fieldErrors.last_name" required><el-input v-model="guest.last_name" /></el-form-item>
        </div>
        <el-form-item label="Email" :error="createForm.fieldErrors.email"><el-input v-model="guest.email" type="email" /></el-form-item>
        <el-form-item label="Téléphone" :error="createForm.fieldErrors.phone"><el-input v-model="guest.phone" type="tel" /></el-form-item>
        <el-form-item label="Pays (code ISO)" :error="createForm.fieldErrors.country_code"><el-input v-model="guest.country_code" maxlength="2" /></el-form-item>
        <el-checkbox v-model="guest.marketing_consent">Accepte de recevoir des communications commerciales</el-checkbox>
      </el-form>
      <template #footer>
        <el-button @click="dialogOpen = false">Annuler</el-button>
        <el-button type="primary" :loading="createForm.submitting.value" @click="create">Créer</el-button>
      </template>
    </el-dialog>
  </div>
</template>
