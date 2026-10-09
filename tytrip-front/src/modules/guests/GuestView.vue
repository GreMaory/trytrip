<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessageBox } from 'element-plus'
import { pmsApi } from '@/api'
import type { Guest } from '@/api/types'
import { useForm, useLoader } from '@/composables/useForm'
import { useAuthStore } from '@/stores/auth'
import { formatDate, formatDateTime, formatMoney } from '@/utils/format'
import StatusTag from '@/components/StatusTag.vue'
import ErrorAlert from '@/components/ErrorAlert.vue'

const props = defineProps<{ id: string }>()
const auth = useAuthStore()
const router = useRouter()
const { loading, error, load } = useLoader()
const { submitting, fieldErrors, error: saveError, submit } = useForm()
const guest = ref<Guest | null>(null)
const editing = ref(false)
const form = reactive<Partial<Guest>>({})

async function fetch() {
  guest.value = (await load(() => pmsApi.guest(Number(props.id)))) ?? null
}
onMounted(fetch)

function edit() {
  const g = guest.value!
  Object.assign(form, { first_name: g.first_name, last_name: g.last_name, email: g.email, phone: g.phone, country_code: g.country_code,
    language: g.language, notes: g.notes, marketing_consent: g.marketing_consent })
  editing.value = true
}

async function save() {
  const saved = await submit(() => pmsApi.updateGuest(Number(props.id), form), 'Voyageur mis à jour')
  if (saved) {
    editing.value = false
    fetch()
  }
}

async function remove() {
  try {
    await ElMessageBox.confirm('Supprimer définitivement ce voyageur et ses données personnelles ?', 'Supprimer', { type: 'warning' })
  } catch { return }
  const done = await submit(async () => { await pmsApi.deleteGuest(Number(props.id)); return true }, 'Voyageur supprimé')
  if (done) router.push('/guests')
}
</script>

<template>
  <div class="page" v-loading="loading">
    <ErrorAlert :message="error || saveError" />
    <template v-if="guest">
      <div class="page-header">
        <h1>{{ guest.full_name }}</h1>
        <div class="actions" v-if="auth.can('guests.manage') && !editing">
          <el-button @click="edit">Modifier</el-button>
          <el-button type="danger" plain @click="remove">Supprimer</el-button>
        </div>
      </div>

      <el-card shadow="never" header="Coordonnées">
        <el-form v-if="editing" label-position="top" class="form-narrow" @submit.prevent="save">
          <div class="grid grid-2">
            <el-form-item label="Prénom" :error="fieldErrors.first_name"><el-input v-model="form.first_name" /></el-form-item>
            <el-form-item label="Nom" :error="fieldErrors.last_name"><el-input v-model="form.last_name" /></el-form-item>
            <el-form-item label="Email" :error="fieldErrors.email"><el-input v-model="form.email" type="email" /></el-form-item>
            <el-form-item label="Téléphone" :error="fieldErrors.phone"><el-input v-model="form.phone" /></el-form-item>
            <el-form-item label="Pays" :error="fieldErrors.country_code"><el-input v-model="form.country_code" maxlength="2" /></el-form-item>
            <el-form-item label="Langue"><el-input v-model="form.language" maxlength="5" /></el-form-item>
          </div>
          <el-form-item label="Notes internes"><el-input v-model="form.notes" type="textarea" :rows="3" /></el-form-item>
          <el-checkbox v-model="form.marketing_consent">Consentement aux communications commerciales</el-checkbox>
          <div style="margin-top: 16px">
            <el-button type="primary" native-type="submit" :loading="submitting">Enregistrer</el-button>
            <el-button @click="editing = false">Annuler</el-button>
          </div>
        </el-form>
        <el-descriptions v-else :column="2" border>
          <el-descriptions-item label="Email">{{ guest.email ?? '—' }}</el-descriptions-item>
          <el-descriptions-item label="Téléphone">{{ guest.phone ?? '—' }}</el-descriptions-item>
          <el-descriptions-item label="Pays">{{ guest.country_code ?? '—' }}</el-descriptions-item>
          <el-descriptions-item label="Langue">{{ guest.language ?? '—' }}</el-descriptions-item>
          <el-descriptions-item label="Marketing">
            {{ guest.marketing_consent ? `Consentement donné le ${formatDateTime(guest.marketing_consent_at)}` : 'Pas de consentement' }}
          </el-descriptions-item>
          <el-descriptions-item label="Client depuis">{{ formatDate(guest.created_at) }}</el-descriptions-item>
          <el-descriptions-item label="Notes" :span="2"><span style="white-space: pre-line">{{ guest.notes || '—' }}</span></el-descriptions-item>
        </el-descriptions>
      </el-card>

      <el-card shadow="never" header="Séjours" style="margin-top: 16px">
        <el-table :data="guest.reservations ?? []" empty-text="Aucun séjour" @row-click="(row: { id: number }) => $router.push(`/reservations/${row.id}`)" style="cursor: pointer">
          <el-table-column prop="reference" label="Réf." width="120" />
          <el-table-column label="Logement"><template #default="{ row }">{{ row.property_name }}</template></el-table-column>
          <el-table-column label="Dates" width="240"><template #default="{ row }">{{ formatDate(row.check_in) }} → {{ formatDate(row.check_out) }}</template></el-table-column>
          <el-table-column label="Montant" width="130" align="right"><template #default="{ row }">{{ formatMoney(row.total_amount, row.currency) }}</template></el-table-column>
          <el-table-column label="Statut" width="140"><template #default="{ row }"><StatusTag :status="row.status" /></template></el-table-column>
        </el-table>
      </el-card>
    </template>
  </div>
</template>
