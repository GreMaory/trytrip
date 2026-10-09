<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { pmsApi } from '@/api'
import { ApiError } from '@/api/client'
import type { Reservation, ReservationEvent } from '@/api/types'
import { useLoader } from '@/composables/useForm'
import { useAuthStore } from '@/stores/auth'
import { formatDate, formatDateTime, formatMoney } from '@/utils/format'
import { reservationEventLabels, reservationSources } from '@/utils/labels'
import StatusTag from '@/components/StatusTag.vue'
import ErrorAlert from '@/components/ErrorAlert.vue'

const props = defineProps<{ id: string }>()
const auth = useAuthStore()
const { loading, error, load } = useLoader()
const reservation = ref<Reservation | null>(null)
const acting = ref(false)

onMounted(async () => {
  reservation.value = (await load(() => pmsApi.reservation(Number(props.id)))) ?? null
})

async function run(event: ReservationEvent) {
  let reason: string | undefined
  try {
    if (event === 'cancel') {
      const result = await ElMessageBox.prompt('Motif d’annulation (facultatif)', 'Annuler la réservation', {
        confirmButtonText: 'Annuler la réservation', cancelButtonText: 'Retour', type: 'warning',
      })
      reason = result.value
    } else if (event === 'mark_no_show') {
      await ElMessageBox.confirm('Marquer le voyageur comme non présenté ?', 'Non présenté', { type: 'warning' })
    }
  } catch {
    return // dialog dismissed
  }

  acting.value = true
  try {
    reservation.value = await pmsApi.transitionReservation(Number(props.id), event, reason)
    ElMessage.success('Réservation mise à jour')
  } catch (err) {
    ElMessage.error(err instanceof ApiError ? err.message : 'Action impossible')
  } finally {
    acting.value = false
  }
}
</script>

<template>
  <div class="page" v-loading="loading">
    <ErrorAlert :message="error" />
    <template v-if="reservation">
      <div class="page-header">
        <div>
          <h1>Réservation {{ reservation.reference }} <StatusTag :status="reservation.status" /></h1>
          <span class="muted">Créée le {{ formatDateTime(reservation.created_at) }} · source : {{ reservationSources[reservation.source] ?? reservation.source }}</span>
        </div>
        <div class="actions" v-if="auth.can('reservations.manage')">
          <el-button v-for="event in reservation.available_events" :key="event" :loading="acting"
            :type="event === 'cancel' || event === 'mark_no_show' ? 'danger' : 'primary'" :plain="event === 'cancel' || event === 'mark_no_show'"
            @click="run(event)">{{ reservationEventLabels[event] }}</el-button>
          <el-button v-if="['pending', 'confirmed'].includes(reservation.status)" @click="$router.push(`/reservations/${reservation.id}/edit`)">Modifier</el-button>
        </div>
      </div>

      <div class="grid grid-2">
        <el-card shadow="never" header="Séjour">
          <el-descriptions :column="1" border>
            <el-descriptions-item label="Logement">
              <RouterLink :to="`/properties/${reservation.unit.property.id}`">{{ reservation.unit.property.name }}</RouterLink>
              <span v-if="reservation.unit.name !== reservation.unit.property.name"> · {{ reservation.unit.name }}</span>
            </el-descriptions-item>
            <el-descriptions-item label="Arrivée">{{ formatDate(reservation.check_in, { dateStyle: 'full' }) }}</el-descriptions-item>
            <el-descriptions-item label="Départ">{{ formatDate(reservation.check_out, { dateStyle: 'full' }) }}</el-descriptions-item>
            <el-descriptions-item label="Durée">{{ reservation.nights }} nuit(s)</el-descriptions-item>
            <el-descriptions-item label="Voyageurs">{{ reservation.adults }} adulte(s), {{ reservation.children }} enfant(s)</el-descriptions-item>
            <el-descriptions-item label="Tarif / nuit">{{ formatMoney(reservation.nightly_rate, reservation.currency) }}</el-descriptions-item>
            <el-descriptions-item label="Montant total"><strong>{{ formatMoney(reservation.total_amount, reservation.currency) }}</strong></el-descriptions-item>
          </el-descriptions>
        </el-card>
        <el-card shadow="never" header="Voyageur">
          <el-descriptions :column="1" border>
            <el-descriptions-item label="Nom"><RouterLink :to="`/guests/${reservation.guest.id}`">{{ reservation.guest.full_name }}</RouterLink></el-descriptions-item>
            <el-descriptions-item label="Email">{{ reservation.guest.email ?? '—' }}</el-descriptions-item>
            <el-descriptions-item label="Téléphone">{{ reservation.guest.phone ?? '—' }}</el-descriptions-item>
          </el-descriptions>
          <h3>Demandes particulières</h3>
          <p class="pre">{{ reservation.special_requests || '—' }}</p>
          <h3>Notes internes</h3>
          <p class="pre">{{ reservation.notes || '—' }}</p>
        </el-card>
      </div>

      <el-card shadow="never" header="Historique" class="section">
        <el-timeline>
          <el-timeline-item :timestamp="formatDateTime(reservation.created_at)">Réservation créée</el-timeline-item>
          <el-timeline-item v-if="reservation.confirmed_at" :timestamp="formatDateTime(reservation.confirmed_at)" type="success">Confirmée</el-timeline-item>
          <el-timeline-item v-if="reservation.checked_in_at" :timestamp="formatDateTime(reservation.checked_in_at)" type="primary">Arrivée enregistrée</el-timeline-item>
          <el-timeline-item v-if="reservation.checked_out_at" :timestamp="formatDateTime(reservation.checked_out_at)">Départ enregistré</el-timeline-item>
          <el-timeline-item v-if="reservation.cancelled_at" :timestamp="formatDateTime(reservation.cancelled_at)" type="danger">
            Annulée<span v-if="reservation.cancellation_reason"> — {{ reservation.cancellation_reason }}</span>
          </el-timeline-item>
        </el-timeline>
      </el-card>
    </template>
  </div>
</template>

<style scoped>
.section { margin-top: 16px; }
.pre { white-space: pre-line; }
h1 { display: flex; align-items: center; gap: 12px; }
h3 { font-size: 14px; margin: 16px 0 4px; }
</style>
