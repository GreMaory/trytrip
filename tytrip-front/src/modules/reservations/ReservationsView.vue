<script setup lang="ts">
import { onMounted, ref, watch } from 'vue'
import { useRoute } from 'vue-router'
import { pmsApi } from '@/api'
import type { Pagination } from '@/api/client'
import type { Reservation, ReservationStatus } from '@/api/types'
import { useLoader } from '@/composables/useForm'
import { useAuthStore } from '@/stores/auth'
import { formatDate, formatMoney } from '@/utils/format'
import { reservationStatusLabels } from '@/utils/labels'
import StatusTag from '@/components/StatusTag.vue'
import ErrorAlert from '@/components/ErrorAlert.vue'

const auth = useAuthStore()
const route = useRoute()
const { loading, error, load } = useLoader()
const reservations = ref<Reservation[]>([])
const pagination = ref<Pagination | null>(null)
const query = ref('')
const statuses = ref<ReservationStatus[]>(typeof route.query.status === 'string' ? [route.query.status as ReservationStatus] : [])
const period = ref<[string, string] | null>(null)
const page = ref(1)

async function fetch() {
  const result = await load(() =>
    pmsApi.reservations({
      q: query.value || undefined,
      status: statuses.value.length ? statuses.value : undefined,
      from: period.value?.[0],
      to: period.value?.[1],
      page: page.value,
    }),
  )
  if (result) {
    reservations.value = result.items
    pagination.value = result.pagination
  }
}

let timer: ReturnType<typeof setTimeout> | undefined
watch(query, () => { clearTimeout(timer); timer = setTimeout(() => { page.value = 1; fetch() }, 300) })
watch([statuses, period], () => { page.value = 1; fetch() })
watch(page, fetch)
onMounted(fetch)
</script>

<template>
  <div class="page">
    <div class="page-header">
      <h1>Réservations</h1>
      <div class="actions"><el-button v-if="auth.can('reservations.manage')" type="primary" @click="$router.push('/reservations/new')">Nouvelle réservation</el-button></div>
    </div>
    <div class="toolbar">
      <el-input v-model="query" placeholder="Référence, nom, email…" clearable aria-label="Rechercher" />
      <el-select v-model="statuses" multiple collapse-tags placeholder="Statuts" style="width: 220px" aria-label="Statuts">
        <el-option v-for="(label, value) in reservationStatusLabels" :key="value" :label="label" :value="value" />
      </el-select>
      <el-date-picker v-model="period" type="daterange" value-format="YYYY-MM-DD" start-placeholder="Du" end-placeholder="Au" aria-label="Période" />
    </div>
    <ErrorAlert :message="error" />
    <el-table v-loading="loading" :data="reservations" empty-text="Aucune réservation"
      @row-click="(row: Reservation) => $router.push(`/reservations/${row.id}`)" style="cursor: pointer">
      <el-table-column prop="reference" label="Réf." width="120" />
      <el-table-column label="Voyageur" min-width="170"><template #default="{ row }">{{ row.guest.full_name }}</template></el-table-column>
      <el-table-column label="Logement" min-width="190">
        <template #default="{ row }">{{ row.unit.property.name }}<span v-if="row.unit.name !== row.unit.property.name" class="muted"> · {{ row.unit.name }}</span></template>
      </el-table-column>
      <el-table-column label="Arrivée" width="130"><template #default="{ row }">{{ formatDate(row.check_in) }}</template></el-table-column>
      <el-table-column label="Départ" width="130"><template #default="{ row }">{{ formatDate(row.check_out) }}</template></el-table-column>
      <el-table-column label="Montant" width="130" align="right"><template #default="{ row }">{{ formatMoney(row.total_amount, row.currency) }}</template></el-table-column>
      <el-table-column label="Statut" width="140"><template #default="{ row }"><StatusTag :status="row.status" /></template></el-table-column>
    </el-table>
    <div class="pagination" v-if="pagination && pagination.total_pages > 1">
      <el-pagination v-model:current-page="page" :page-size="pagination.per_page" :total="pagination.total" layout="prev, pager, next" />
    </div>
  </div>
</template>
