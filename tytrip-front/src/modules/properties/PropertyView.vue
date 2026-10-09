<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import { ElMessageBox } from 'element-plus'
import { pmsApi } from '@/api'
import type { Property, Unit } from '@/api/types'
import { useForm, useLoader } from '@/composables/useForm'
import { useAuthStore } from '@/stores/auth'
import { formatMoney } from '@/utils/format'
import { amenityLabels, propertyTypes } from '@/utils/labels'
import ErrorAlert from '@/components/ErrorAlert.vue'

const props = defineProps<{ id: string }>()
const auth = useAuthStore()
const { loading, error, load } = useLoader()
const unitForm = useForm()
const property = ref<Property | null>(null)
const dialogOpen = ref(false)
const editing = ref<Unit | null>(null)
const unit = reactive<Partial<Unit>>({})

async function fetch() {
  property.value = (await load(() => pmsApi.property(Number(props.id)))) ?? null
}
onMounted(fetch)

function openUnit(existing?: Unit) {
  editing.value = existing ?? null
  Object.assign(unit, existing ?? { name: '', max_guests: 2, bedrooms: 1, beds: 1, bathrooms: '1', base_rate: '100.00', min_stay: 1, max_stay: null, status: 'active' })
  unitForm.reset()
  dialogOpen.value = true
}

async function saveUnit() {
  const { id: _id, property_id: _p, property_name: _n, ...attributes } = unit
  const saved = await unitForm.submit(
    () => (editing.value ? pmsApi.updateUnit(editing.value.id, attributes) : pmsApi.createUnit(Number(props.id), attributes)),
    'Logement enregistré',
  )
  if (saved) {
    dialogOpen.value = false
    fetch()
  }
}

async function archive() {
  await ElMessageBox.confirm('Archiver cette propriété ? Elle ne sera plus proposée à la réservation.', 'Archiver', { type: 'warning' })
  await pmsApi.archiveProperty(Number(props.id))
  fetch()
}
</script>

<template>
  <div class="page" v-loading="loading">
    <ErrorAlert :message="error" />
    <template v-if="property">
      <div class="page-header">
        <div>
          <h1>{{ property.name }}</h1>
          <span class="muted">{{ propertyTypes[property.property_type] }} · {{ [property.city, property.country_code].filter(Boolean).join(', ') || 'Adresse non renseignée' }}</span>
        </div>
        <div class="actions" v-if="auth.can('properties.manage')">
          <el-button @click="$router.push(`/properties/${property.id}/edit`)">Modifier</el-button>
          <el-button v-if="property.status === 'active'" type="danger" plain @click="archive">Archiver</el-button>
        </div>
      </div>

      <div class="grid grid-2">
        <el-card shadow="never" header="Informations">
          <el-descriptions :column="1" border>
            <el-descriptions-item label="Adresse">{{ [property.address_line1, property.address_line2, property.postal_code, property.city].filter(Boolean).join(', ') || '—' }}</el-descriptions-item>
            <el-descriptions-item label="Arrivée / départ">{{ property.check_in_time }} / {{ property.check_out_time }}</el-descriptions-item>
            <el-descriptions-item label="Fuseau horaire">{{ property.time_zone }}</el-descriptions-item>
            <el-descriptions-item label="Statut">{{ property.status === 'active' ? 'Active' : 'Archivée' }}</el-descriptions-item>
          </el-descriptions>
          <p v-if="property.description" class="pre">{{ property.description }}</p>
          <div class="tags"><el-tag v-for="amenity in property.amenities" :key="amenity" type="info">{{ amenityLabels[amenity] ?? amenity }}</el-tag></div>
        </el-card>
        <el-card shadow="never" header="Règles et accès">
          <h3>Règlement intérieur</h3>
          <p class="pre">{{ property.house_rules || '—' }}</p>
          <h3>Instructions d’accès</h3>
          <p class="pre">{{ property.access_instructions || '—' }}</p>
        </el-card>
      </div>

      <el-card shadow="never" class="section">
        <template #header>
          <div class="card-header">
            <span>Logements</span>
            <el-button v-if="auth.can('properties.manage')" size="small" @click="openUnit()">Ajouter un logement</el-button>
          </div>
        </template>
        <el-table :data="property.units" empty-text="Aucun logement">
          <el-table-column prop="name" label="Nom" />
          <el-table-column prop="max_guests" label="Capacité" width="100" />
          <el-table-column label="Tarif / nuit" width="130"><template #default="{ row }">{{ formatMoney(row.base_rate, auth.organization?.currency) }}</template></el-table-column>
          <el-table-column label="Séjour" width="140"><template #default="{ row }">{{ row.min_stay }}{{ row.max_stay ? `–${row.max_stay}` : '+' }} nuits</template></el-table-column>
          <el-table-column label="Statut" width="100"><template #default="{ row }">{{ row.status === 'active' ? 'Actif' : 'Inactif' }}</template></el-table-column>
          <el-table-column v-if="auth.can('properties.manage')" width="100">
            <template #default="{ row }"><el-button size="small" text @click="openUnit(row)">Modifier</el-button></template>
          </el-table-column>
        </el-table>
      </el-card>
    </template>

    <el-dialog v-model="dialogOpen" :title="editing ? 'Modifier le logement' : 'Nouveau logement'" width="560px">
      <ErrorAlert :message="unitForm.error.value" />
      <el-form label-position="top" @submit.prevent="saveUnit">
        <el-form-item label="Nom" :error="unitForm.fieldErrors.name" required><el-input v-model="unit.name" /></el-form-item>
        <div class="grid grid-2">
          <el-form-item label="Capacité" :error="unitForm.fieldErrors.max_guests"><el-input-number v-model="unit.max_guests" :min="1" /></el-form-item>
          <el-form-item label="Tarif de base / nuit" :error="unitForm.fieldErrors.base_rate"><el-input v-model="unit.base_rate" inputmode="decimal" /></el-form-item>
          <el-form-item label="Chambres"><el-input-number v-model="unit.bedrooms" :min="0" /></el-form-item>
          <el-form-item label="Lits"><el-input-number v-model="unit.beds" :min="0" /></el-form-item>
          <el-form-item label="Séjour minimum" :error="unitForm.fieldErrors.min_stay"><el-input-number v-model="unit.min_stay" :min="1" /></el-form-item>
          <el-form-item label="Séjour maximum" :error="unitForm.fieldErrors.max_stay"><el-input-number v-model="unit.max_stay" :min="1" :value-on-clear="null" /></el-form-item>
        </div>
        <el-form-item label="Statut">
          <el-radio-group v-model="unit.status"><el-radio value="active">Actif</el-radio><el-radio value="inactive">Inactif</el-radio></el-radio-group>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogOpen = false">Annuler</el-button>
        <el-button type="primary" :loading="unitForm.submitting.value" @click="saveUnit">Enregistrer</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<style scoped>
.section { margin-top: 16px; }
.card-header { display: flex; justify-content: space-between; align-items: center; }
.pre { white-space: pre-line; }
.tags { display: flex; gap: 6px; flex-wrap: wrap; margin-top: 12px; }
h3 { font-size: 14px; margin: 12px 0 4px; }
</style>
