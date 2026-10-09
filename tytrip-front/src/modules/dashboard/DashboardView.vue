<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { pmsApi } from '@/api'
import type { Dashboard } from '@/api/types'
import { useLoader } from '@/composables/useForm'
import { useAuthStore } from '@/stores/auth'
import { formatDate, formatMoney, formatPercent } from '@/utils/format'
import StatusTag from '@/components/StatusTag.vue'
import ErrorAlert from '@/components/ErrorAlert.vue'

const auth = useAuthStore()
const { loading, error, load } = useLoader()
const dashboard = ref<Dashboard | null>(null)

onMounted(async () => {
  dashboard.value = (await load(() => pmsApi.dashboard())) ?? null
})
</script>

<template>
  <div class="page" v-loading="loading">
    <div class="page-header">
      <h1>Tableau de bord</h1>
      <div class="actions" v-if="auth.can('reservations.manage')">
        <el-button type="primary" @click="$router.push('/reservations/new')">Nouvelle réservation</el-button>
      </div>
    </div>
    <ErrorAlert :message="error" />

    <template v-if="dashboard">
      <p class="muted">{{ formatDate(dashboard.date, { dateStyle: 'full' }) }}</p>
      <div class="grid grid-4">
        <el-card shadow="never"><div class="muted">Arrivées du jour</div><div class="stat-value">{{ dashboard.arrivals.length }}</div></el-card>
        <el-card shadow="never"><div class="muted">Départs du jour</div><div class="stat-value">{{ dashboard.departures.length }}</div></el-card>
        <el-card shadow="never"><div class="muted">Séjours en cours</div><div class="stat-value">{{ dashboard.in_house_count }}</div></el-card>
        <el-card shadow="never">
          <div class="muted">Occupation (30 prochains jours)</div>
          <div class="stat-value">{{ formatPercent(dashboard.occupancy_rate) }}</div>
          <div class="muted">{{ dashboard.units_count }} logement(s) actif(s)</div>
        </el-card>
        <el-card shadow="never">
          <div class="muted">Chiffre d’affaires du mois</div>
          <div class="stat-value">{{ formatMoney(dashboard.revenue_month.amount, dashboard.revenue_month.currency) }}</div>
          <div class="muted">Séjours débutant ce mois, hors annulations</div>
        </el-card>
        <el-card shadow="never">
          <div class="muted">Réservations à confirmer</div>
          <div class="stat-value">{{ dashboard.pending_count }}</div>
          <RouterLink :to="{ path: '/reservations', query: { status: 'pending' } }">Voir</RouterLink>
        </el-card>
      </div>

      <div class="grid grid-2" style="margin-top: 16px">
        <el-card v-for="block in [{ title: 'Arrivées', rows: dashboard.arrivals }, { title: 'Départs', rows: dashboard.departures }]"
          :key="block.title" shadow="never" :header="block.title">
          <el-empty v-if="!block.rows.length" :image-size="60" description="Aucun mouvement aujourd’hui" />
          <el-table v-else :data="block.rows" @row-click="(row: { id: number }) => $router.push(`/reservations/${row.id}`)" style="cursor: pointer">
            <el-table-column prop="guest_name" label="Voyageur" />
            <el-table-column label="Logement">
              <template #default="{ row }">{{ row.property_name }}<span v-if="row.unit_name !== row.property_name"> · {{ row.unit_name }}</span></template>
            </el-table-column>
            <el-table-column label="Statut" width="140"><template #default="{ row }"><StatusTag :status="row.status" /></template></el-table-column>
          </el-table>
        </el-card>
      </div>
    </template>
  </div>
</template>
