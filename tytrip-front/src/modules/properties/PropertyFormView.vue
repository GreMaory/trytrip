<script setup lang="ts">
import { onMounted, reactive } from 'vue'
import { useRouter } from 'vue-router'
import { pmsApi } from '@/api'
import type { Property } from '@/api/types'
import { useForm, useLoader } from '@/composables/useForm'
import { amenityLabels, propertyTypes } from '@/utils/labels'
import ErrorAlert from '@/components/ErrorAlert.vue'

const props = defineProps<{ id?: string }>()
const router = useRouter()
const { loading, load } = useLoader()
const { submitting, fieldErrors, error, submit } = useForm()

const form = reactive<Partial<Property>>({
  name: '', property_type: 'apartment', description: '', address_line1: '', address_line2: '', postal_code: '', city: '',
  country_code: 'FR', time_zone: 'Europe/Paris', check_in_time: '16:00', check_out_time: '11:00', house_rules: '',
  access_instructions: '', amenities: [],
})
const unit = reactive({ max_guests: 2, bedrooms: 1, beds: 1, bathrooms: '1', base_rate: '100.00', min_stay: 1 })

onMounted(async () => {
  if (!props.id) return
  const property = await load(() => pmsApi.property(Number(props.id)))
  if (property) Object.assign(form, property)
})

async function save() {
  const { units: _units, id: _id, created_at: _c, updated_at: _u, ...attributes } = form
  const property = await submit(
    () => (props.id ? pmsApi.updateProperty(Number(props.id), attributes) : pmsApi.createProperty(attributes, unit)),
    'Propriété enregistrée',
  )
  if (property) router.push(`/properties/${property.id}`)
}
</script>

<template>
  <div class="page" v-loading="loading">
    <div class="page-header"><h1>{{ id ? 'Modifier la propriété' : 'Nouvelle propriété' }}</h1></div>
    <ErrorAlert :message="error" />
    <el-form label-position="top" class="form-narrow" @submit.prevent="save">
      <el-card shadow="never" header="Informations générales">
        <el-form-item label="Nom" :error="fieldErrors.name" required><el-input v-model="form.name" /></el-form-item>
        <el-form-item label="Type" :error="fieldErrors.property_type">
          <el-select v-model="form.property_type"><el-option v-for="(label, value) in propertyTypes" :key="value" :label="label" :value="value" /></el-select>
        </el-form-item>
        <el-form-item label="Description"><el-input v-model="form.description" type="textarea" :rows="4" /></el-form-item>
        <el-form-item label="Équipements" :error="fieldErrors.amenities">
          <el-checkbox-group v-model="form.amenities">
            <el-checkbox v-for="(label, value) in amenityLabels" :key="value" :value="value">{{ label }}</el-checkbox>
          </el-checkbox-group>
        </el-form-item>
      </el-card>

      <el-card shadow="never" header="Adresse" class="section">
        <el-form-item label="Adresse"><el-input v-model="form.address_line1" autocomplete="address-line1" /></el-form-item>
        <el-form-item label="Complément"><el-input v-model="form.address_line2" autocomplete="address-line2" /></el-form-item>
        <div class="grid grid-2">
          <el-form-item label="Code postal"><el-input v-model="form.postal_code" /></el-form-item>
          <el-form-item label="Ville"><el-input v-model="form.city" /></el-form-item>
          <el-form-item label="Pays (code ISO)" :error="fieldErrors.country_code"><el-input v-model="form.country_code" maxlength="2" /></el-form-item>
          <el-form-item label="Fuseau horaire" :error="fieldErrors.time_zone"><el-input v-model="form.time_zone" /></el-form-item>
        </div>
      </el-card>

      <el-card shadow="never" header="Séjour" class="section">
        <div class="grid grid-2">
          <el-form-item label="Arrivée à partir de" :error="fieldErrors.check_in_time"><el-time-select v-model="form.check_in_time" start="06:00" end="23:30" step="00:30" /></el-form-item>
          <el-form-item label="Départ avant" :error="fieldErrors.check_out_time"><el-time-select v-model="form.check_out_time" start="06:00" end="23:30" step="00:30" /></el-form-item>
        </div>
        <el-form-item label="Règlement intérieur"><el-input v-model="form.house_rules" type="textarea" :rows="3" /></el-form-item>
        <el-form-item label="Instructions d’accès (internes, transmises aux voyageurs confirmés)"><el-input v-model="form.access_instructions" type="textarea" :rows="3" /></el-form-item>
      </el-card>

      <el-card v-if="!id" shadow="never" header="Logement" class="section">
        <p class="muted">Un premier logement est créé avec la propriété. Vous pourrez en ajouter d’autres ensuite.</p>
        <div class="grid grid-2">
          <el-form-item label="Capacité (voyageurs)"><el-input-number v-model="unit.max_guests" :min="1" :max="100" /></el-form-item>
          <el-form-item label="Tarif de base par nuit"><el-input v-model="unit.base_rate" inputmode="decimal" /></el-form-item>
          <el-form-item label="Chambres"><el-input-number v-model="unit.bedrooms" :min="0" /></el-form-item>
          <el-form-item label="Lits"><el-input-number v-model="unit.beds" :min="0" /></el-form-item>
          <el-form-item label="Durée minimale (nuits)"><el-input-number v-model="unit.min_stay" :min="1" /></el-form-item>
        </div>
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
</style>
