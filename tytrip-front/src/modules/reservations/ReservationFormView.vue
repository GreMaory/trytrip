<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { pmsApi } from '@/api'
import type { Guest, Unit } from '@/api/types'
import { useForm, useLoader } from '@/composables/useForm'
import { useAuthStore } from '@/stores/auth'
import { daysBetween, formatMoney } from '@/utils/format'
import { reservationSources } from '@/utils/labels'
import ErrorAlert from '@/components/ErrorAlert.vue'

const props = defineProps<{ id?: string }>()
const route = useRoute()
const router = useRouter()
const auth = useAuthStore()
const { loading, load } = useLoader()
const { submitting, fieldErrors, error, submit } = useForm()

const units = ref<Unit[]>([])
const guestMode = ref<'existing' | 'new'>('new')
const guestOptions = ref<Guest[]>([])
const searchingGuests = ref(false)
const form = reactive({
  unit_id: route.query.unit_id ? Number(route.query.unit_id) : (undefined as number | undefined),
  dates: (route.query.check_in && route.query.check_out ? [String(route.query.check_in), String(route.query.check_out)] : null) as [string, string] | null,
  adults: 2,
  children: 0,
  source: 'direct',
  nightly_rate: '' as string,
  notes: '',
  special_requests: '',
  guest_id: undefined as number | undefined,
})
const guest = reactive({ first_name: '', last_name: '', email: '', phone: '' })

const selectedUnit = computed(() => units.value.find((unit) => unit.id === form.unit_id))
const nights = computed(() => (form.dates ? daysBetween(form.dates[0], form.dates[1]) : 0))
const estimate = computed(() => {
  const rate = form.nightly_rate || selectedUnit.value?.base_rate
  return rate && nights.value > 0 ? (Number(rate) * nights.value).toFixed(2) : null
})

onMounted(async () => {
  await load(async () => {
    units.value = await pmsApi.units()
    if (props.id) {
      const reservation = await pmsApi.reservation(Number(props.id))
      Object.assign(form, {
        unit_id: reservation.unit.id, dates: [reservation.check_in, reservation.check_out], adults: reservation.adults,
        children: reservation.children, source: reservation.source, nightly_rate: reservation.nightly_rate,
        notes: reservation.notes ?? '', special_requests: reservation.special_requests ?? '', guest_id: reservation.guest.id,
      })
      guestOptions.value = [reservation.guest]
      guestMode.value = 'existing'
    }
  })
})

async function searchGuests(term: string) {
  if (term.length < 2) return
  searchingGuests.value = true
  try {
    guestOptions.value = (await pmsApi.guests({ q: term, per_page: 20 })).items
  } finally {
    searchingGuests.value = false
  }
}

async function save() {
  const reservation: Record<string, unknown> = {
    unit_id: form.unit_id, check_in: form.dates?.[0], check_out: form.dates?.[1], adults: form.adults, children: form.children,
    source: form.source, notes: form.notes, special_requests: form.special_requests,
  }
  if (form.nightly_rate) reservation.nightly_rate = form.nightly_rate
  if (guestMode.value === 'existing') reservation.guest_id = form.guest_id

  const saved = await submit(
    () => (props.id
      ? pmsApi.updateReservation(Number(props.id), reservation)
      : pmsApi.createReservation(reservation, guestMode.value === 'new' ? guest : undefined)),
    'Réservation enregistrée',
  )
  if (saved) router.push(`/reservations/${saved.id}`)
}
</script>

<template>
  <div class="page" v-loading="loading">
    <div class="page-header"><h1>{{ id ? 'Modifier la réservation' : 'Nouvelle réservation' }}</h1></div>
    <ErrorAlert :message="error" />
    <el-form label-position="top" class="form-narrow" @submit.prevent="save">
      <el-card shadow="never" header="Séjour">
        <el-form-item label="Logement" :error="fieldErrors.unit" required>
          <el-select v-model="form.unit_id" filterable placeholder="Choisir un logement">
            <el-option v-for="unit in units" :key="unit.id" :value="unit.id"
              :label="unit.name === unit.property_name ? unit.name : `${unit.property_name} · ${unit.name}`">
              <span>{{ unit.name === unit.property_name ? unit.name : `${unit.property_name} · ${unit.name}` }}</span>
              <span class="muted option-hint">{{ unit.max_guests }} pers. · {{ formatMoney(unit.base_rate, auth.organization?.currency) }}</span>
            </el-option>
          </el-select>
        </el-form-item>
        <el-form-item label="Dates (arrivée – départ)" :error="fieldErrors.check_out || fieldErrors.check_in" required>
          <el-date-picker v-model="form.dates" type="daterange" value-format="YYYY-MM-DD" start-placeholder="Arrivée" end-placeholder="Départ" />
        </el-form-item>
        <div class="grid grid-2">
          <el-form-item label="Adultes" :error="fieldErrors.adults"><el-input-number v-model="form.adults" :min="1" :max="selectedUnit?.max_guests ?? 100" /></el-form-item>
          <el-form-item label="Enfants" :error="fieldErrors.children"><el-input-number v-model="form.children" :min="0" /></el-form-item>
          <el-form-item label="Source">
            <el-select v-model="form.source"><el-option v-for="(label, value) in reservationSources" :key="value" :label="label" :value="value" /></el-select>
          </el-form-item>
          <el-form-item label="Tarif / nuit (vide = tarif du logement)" :error="fieldErrors.nightly_rate">
            <el-input v-model="form.nightly_rate" :placeholder="selectedUnit?.base_rate" inputmode="decimal" />
          </el-form-item>
        </div>
        <p v-if="estimate" class="muted">
          {{ nights }} nuit(s) — montant indicatif : <strong>{{ formatMoney(estimate, auth.organization?.currency) }}</strong>
          (le montant définitif est calculé par le serveur)
        </p>
      </el-card>

      <el-card shadow="never" header="Voyageur" class="section">
        <el-radio-group v-if="!id" v-model="guestMode" class="mb">
          <el-radio-button value="new">Nouveau voyageur</el-radio-button>
          <el-radio-button value="existing">Voyageur existant</el-radio-button>
        </el-radio-group>
        <el-form-item v-if="guestMode === 'existing'" label="Voyageur" :error="fieldErrors.guest" required>
          <el-select v-model="form.guest_id" filterable remote :remote-method="searchGuests" :loading="searchingGuests" placeholder="Rechercher par nom ou email">
            <el-option v-for="option in guestOptions" :key="option.id" :value="option.id" :label="option.full_name">
              {{ option.full_name }} <span class="muted">{{ option.email }}</span>
            </el-option>
          </el-select>
        </el-form-item>
        <div v-else class="grid grid-2">
          <el-form-item label="Prénom" :error="fieldErrors.first_name" required><el-input v-model="guest.first_name" /></el-form-item>
          <el-form-item label="Nom" :error="fieldErrors.last_name" required><el-input v-model="guest.last_name" /></el-form-item>
          <el-form-item label="Email" :error="fieldErrors.email"><el-input v-model="guest.email" type="email" /></el-form-item>
          <el-form-item label="Téléphone" :error="fieldErrors.phone"><el-input v-model="guest.phone" type="tel" /></el-form-item>
        </div>
        <el-form-item label="Demandes particulières"><el-input v-model="form.special_requests" type="textarea" :rows="2" /></el-form-item>
        <el-form-item label="Notes internes"><el-input v-model="form.notes" type="textarea" :rows="2" /></el-form-item>
      </el-card>

      <div class="section">
        <el-button type="primary" native-type="submit" :loading="submitting">Enregistrer</el-button>
        <el-button @click="$router.back()">Annuler</el-button>
      </div>
    </el-form>
  </div>
</template>

<style scoped>
.section { margin-top: 16px; }
.mb { margin-bottom: 16px; }
.option-hint { float: right; margin-left: 16px; font-size: 12px; }
</style>
