<script setup lang="ts">
import { onMounted, ref, watch } from 'vue'
import { pmsApi } from '@/api'
import type { Pagination } from '@/api/client'
import type { Property } from '@/api/types'
import { useLoader } from '@/composables/useForm'
import { useAuthStore } from '@/stores/auth'
import { formatMoney } from '@/utils/format'
import { propertyTypes } from '@/utils/labels'
import ErrorAlert from '@/components/ErrorAlert.vue'

const auth = useAuthStore()
const { loading, error, load } = useLoader()
const properties = ref<Property[]>([])
const pagination = ref<Pagination | null>(null)
const query = ref('')
const status = ref<'active' | 'archived' | 'all'>('active')
const page = ref(1)

async function fetch() {
  const result = await load(() => pmsApi.properties({ q: query.value || undefined, status: status.value, page: page.value }))
  if (result) {
    properties.value = result.items
    pagination.value = result.pagination
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
      <h1>Propriétés</h1>
      <div class="actions"><el-button v-if="auth.can('properties.manage')" type="primary" @click="$router.push('/properties/new')">Nouvelle propriété</el-button></div>
    </div>
    <div class="toolbar">
      <el-input v-model="query" placeholder="Rechercher une propriété" clearable aria-label="Rechercher" />
      <el-segmented v-model="status" :options="[{ label: 'Actives', value: 'active' }, { label: 'Archivées', value: 'archived' }, { label: 'Toutes', value: 'all' }]" />
    </div>
    <ErrorAlert :message="error" />
    <el-table v-loading="loading" :data="properties" empty-text="Aucune propriété" @row-click="(row: Property) => $router.push(`/properties/${row.id}`)" style="cursor: pointer">
      <el-table-column prop="name" label="Nom" min-width="200" />
      <el-table-column label="Type" width="150"><template #default="{ row }">{{ propertyTypes[row.property_type] ?? row.property_type }}</template></el-table-column>
      <el-table-column label="Ville" min-width="140"><template #default="{ row }">{{ row.city ?? '—' }}</template></el-table-column>
      <el-table-column label="Logements" width="110"><template #default="{ row }">{{ row.units.length }}</template></el-table-column>
      <el-table-column label="À partir de" width="140">
        <template #default="{ row }">{{ row.units.length ? formatMoney(Math.min(...row.units.map((u: { base_rate: string }) => Number(u.base_rate))), auth.organization?.currency) : '—' }}</template>
      </el-table-column>
      <el-table-column label="Statut" width="110">
        <template #default="{ row }"><el-tag :type="row.status === 'active' ? 'success' : 'info'">{{ row.status === 'active' ? 'Active' : 'Archivée' }}</el-tag></template>
      </el-table-column>
    </el-table>
    <div class="pagination" v-if="pagination && pagination.total_pages > 1">
      <el-pagination v-model:current-page="page" :page-size="pagination.per_page" :total="pagination.total" layout="prev, pager, next" />
    </div>
  </div>
</template>
