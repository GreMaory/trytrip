<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage, ElMessageBox } from 'element-plus'
import { pmsApi } from '@/api'
import type { AvailabilityBlock, CalendarData } from '@/api/types'
import { useForm, useLoader } from '@/composables/useForm'
import { useAuthStore } from '@/stores/auth'
import { addDays, daysBetween, formatDate, parseISODate, toISODate } from '@/utils/format'
import { blockReasons, reservationStatusLabels } from '@/utils/labels'
import ErrorAlert from '@/components/ErrorAlert.vue'

const DAYS = 28
const auth = useAuthStore()
const router = useRouter()
const { loading, error, load } = useLoader()
const blockForm = useForm()
const start = ref(toISODate(new Date()))
const calendar = ref<CalendarData | null>(null)
const blockDialog = ref(false)
const block = reactive({ unit_id: 0, dates: null as [string, string] | null, reason: 'owner', note: '' })

const days = computed(() => Array.from({ length: DAYS }, (_, i) => addDays(start.value, i)))
const today = toISODate(new Date())

async function fetch() {
  calendar.value = (await load(() => pmsApi.calendar({ from: start.value, to: addDays(start.value, DAYS) }))) ?? null
}
onMounted(fetch)

function shift(days: number) {
  start.value = addDays(start.value, days)
  fetch()
}

/** Grid placement of a stay: columns are days, a stay spans check-in to check-out. */
function span(from: string, to: string) {
  const first = Math.max(0, daysBetween(start.value, from))
  const last = Math.min(DAYS, daysBetween(start.value, to))
  return { gridColumn: `${first + 2} / ${last + 2}` }
}

function dayLabel(day: string) {
  const date = parseISODate(day)
  return { weekday: date.toLocaleDateString('fr-FR', { weekday: 'narrow' }), day: date.getDate() }
}

function onCellClick(unitId: number, day: string) {
  if (!auth.can('reservations.manage')) return
  router.push({ path: '/reservations/new', query: { unit_id: unitId, check_in: day, check_out: addDays(day, 1) } })
}

function openBlock(unitId: number) {
  Object.assign(block, { unit_id: unitId, dates: null, reason: 'owner', note: '' })
  blockForm.reset()
  blockDialog.value = true
}

async function saveBlock() {
  const saved = await blockForm.submit(() =>
    pmsApi.createBlock({ unit_id: block.unit_id, starts_on: block.dates?.[0] ?? '', ends_on: block.dates?.[1] ?? '', reason: block.reason, note: block.note }),
  'Période bloquée')
  if (saved) {
    blockDialog.value = false
    fetch()
  }
}

async function removeBlock(item: AvailabilityBlock) {
  if (!auth.can('reservations.manage')) return
  try {
    await ElMessageBox.confirm(`Débloquer la période du ${formatDate(item.starts_on)} au ${formatDate(item.ends_on)} ?`, 'Blocage', { type: 'warning' })
  } catch { return }
  await pmsApi.deleteBlock(item.id)
  ElMessage.success('Période débloquée')
  fetch()
}
</script>

<template>
  <div class="page">
    <div class="page-header">
      <h1>Calendrier</h1>
      <div class="actions">
        <el-button @click="shift(-7)" aria-label="Semaine précédente">‹</el-button>
        <el-date-picker v-model="start" type="date" value-format="YYYY-MM-DD" :clearable="false" @change="fetch" aria-label="Début de période" />
        <el-button @click="shift(7)" aria-label="Semaine suivante">›</el-button>
        <el-button @click="start = today; fetch()">Aujourd’hui</el-button>
      </div>
    </div>
    <ErrorAlert :message="error" />

    <div class="calendar" v-loading="loading" role="grid" aria-label="Planning des logements">
      <div class="row header" :style="{ gridTemplateColumns: `200px repeat(${DAYS}, minmax(34px, 1fr))` }">
        <div class="unit-cell">Logement</div>
        <div v-for="day in days" :key="day" class="day" :class="{ today: day === today, weekend: [0, 6].includes(parseISODate(day).getDay()) }">
          <span class="muted">{{ dayLabel(day).weekday }}</span><br>{{ dayLabel(day).day }}
        </div>
      </div>
      <el-empty v-if="calendar && !calendar.units.length" description="Aucun logement actif" />
      <div v-for="unit in calendar?.units" :key="unit.id" class="row" :style="{ gridTemplateColumns: `200px repeat(${DAYS}, minmax(34px, 1fr))` }">
        <div class="unit-cell">
          <strong>{{ unit.property.name }}</strong>
          <span v-if="unit.name !== unit.property.name" class="muted"> · {{ unit.name }}</span>
          <el-button v-if="auth.can('reservations.manage')" link size="small" @click="openBlock(unit.id)">Bloquer</el-button>
        </div>
        <button v-for="(day, index) in days" :key="day" class="cell" :class="{ today: day === today }" :style="{ gridColumn: index + 2, gridRow: 1 }"
          :aria-label="`Créer une réservation le ${formatDate(day)}`" @click="onCellClick(unit.id, day)" />
        <RouterLink v-for="reservation in unit.reservations" :key="`r${reservation.id}`" class="bar" :class="reservation.status"
          :style="{ ...span(reservation.check_in, reservation.check_out), gridRow: 1 }" :to="`/reservations/${reservation.id}`"
          :title="`${reservation.guest_name} · ${reservationStatusLabels[reservation.status]} · ${formatDate(reservation.check_in)} → ${formatDate(reservation.check_out)}`">
          {{ reservation.guest_name }}
        </RouterLink>
        <button v-for="item in unit.blocks" :key="`b${item.id}`" class="bar blocked" :style="{ ...span(item.starts_on, item.ends_on), gridRow: 1 }"
          :title="`${blockReasons[item.reason]}${item.note ? ' — ' + item.note : ''}`" @click="removeBlock(item)">
          {{ blockReasons[item.reason] }}
        </button>
      </div>
    </div>

    <div class="legend">
      <span class="bar pending">En attente</span><span class="bar confirmed">Confirmée</span>
      <span class="bar checked_in">Arrivé</span><span class="bar checked_out">Parti</span><span class="bar blocked">Bloqué</span>
    </div>

    <el-dialog v-model="blockDialog" title="Bloquer une période" width="480px">
      <ErrorAlert :message="blockForm.error.value" />
      <el-form label-position="top">
        <el-form-item label="Période (le dernier jour est libre)" :error="blockForm.fieldErrors.ends_on" required>
          <el-date-picker v-model="block.dates" type="daterange" value-format="YYYY-MM-DD" />
        </el-form-item>
        <el-form-item label="Motif">
          <el-select v-model="block.reason"><el-option v-for="(label, value) in blockReasons" :key="value" :label="label" :value="value" /></el-select>
        </el-form-item>
        <el-form-item label="Note"><el-input v-model="block.note" maxlength="255" /></el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="blockDialog = false">Annuler</el-button>
        <el-button type="primary" :loading="blockForm.submitting.value" @click="saveBlock">Bloquer</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<style scoped>
.calendar { background: #fff; border: 1px solid var(--el-border-color-light); border-radius: 8px; overflow-x: auto; }
.row { display: grid; align-items: stretch; min-width: 1100px; border-bottom: 1px solid var(--el-border-color-lighter); position: relative; }
.row.header { font-size: 12px; text-align: center; background: var(--el-fill-color-lighter); }
.unit-cell { padding: 10px; font-size: 13px; grid-row: 1; grid-column: 1; border-right: 1px solid var(--el-border-color-lighter); text-align: left; }
.day { padding: 6px 0; grid-row: 1; }
.day.weekend { background: var(--el-fill-color); }
.day.today, .cell.today { background: var(--el-color-primary-light-9); }
.cell { border: none; border-left: 1px solid var(--el-border-color-extra-light); background: transparent; min-height: 44px; cursor: pointer; padding: 0; }
.cell:hover { background: var(--el-fill-color-light); }
.bar { align-self: center; margin: 0 2px; padding: 4px 8px; border-radius: 6px; font-size: 12px; color: #fff; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; z-index: 1; border: none; cursor: pointer; text-align: left; }
.bar:hover { text-decoration: none; filter: brightness(0.95); }
.pending { background: var(--el-color-warning); }
.confirmed { background: var(--el-color-success); }
.checked_in { background: var(--el-color-primary); }
.checked_out { background: var(--el-color-info); }
.blocked { background: repeating-linear-gradient(45deg, #909399, #909399 6px, #a6a9ad 6px, #a6a9ad 12px); }
.legend { display: flex; gap: 8px; margin-top: 12px; flex-wrap: wrap; }
.legend .bar { cursor: default; }
</style>
