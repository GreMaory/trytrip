<script setup lang="ts">
import { onMounted, reactive } from 'vue'
import { organizationApi } from '@/api'
import type { Organization } from '@/api/types'
import { useForm, useLoader } from '@/composables/useForm'
import { useAuthStore } from '@/stores/auth'
import ErrorAlert from '@/components/ErrorAlert.vue'

const auth = useAuthStore()
const { loading, load } = useLoader()
const { submitting, fieldErrors, error, submit } = useForm()
const form = reactive<Partial<Organization>>({})

onMounted(async () => {
  const organization = await load(() => organizationApi.show())
  if (organization) Object.assign(form, organization)
})

async function save() {
  const { name, time_zone, locale, currency } = form
  const saved = await submit(() => organizationApi.update({ name, time_zone, locale, currency }), 'Organisation mise à jour')
  if (saved) await auth.fetchMe()
}
</script>

<template>
  <div class="page" v-loading="loading">
    <div class="page-header"><h1>Organisation</h1></div>
    <ErrorAlert :message="error" />
    <el-card shadow="never" class="form-narrow">
      <el-form label-position="top" @submit.prevent="save">
        <el-form-item label="Nom" :error="fieldErrors.name" required><el-input v-model="form.name" /></el-form-item>
        <el-form-item label="Adresse de l’espace"><el-input :model-value="form.host" disabled /></el-form-item>
        <div class="grid grid-2">
          <el-form-item label="Fuseau horaire" :error="fieldErrors.time_zone"><el-input v-model="form.time_zone" /></el-form-item>
          <el-form-item label="Devise" :error="fieldErrors.currency"><el-input v-model="form.currency" maxlength="3" /></el-form-item>
          <el-form-item label="Langue" :error="fieldErrors.locale">
            <el-select v-model="form.locale"><el-option label="Français" value="fr" /><el-option label="English" value="en" /></el-select>
          </el-form-item>
        </div>
        <el-button type="primary" native-type="submit" :loading="submitting">Enregistrer</el-button>
      </el-form>
    </el-card>
  </div>
</template>
