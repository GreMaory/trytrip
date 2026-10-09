<script setup lang="ts">
import { reactive, ref, watch } from 'vue'
import { authApi } from '@/api'
import { useForm } from '@/composables/useForm'
import { appDomain, urlOn } from '@/utils/host'
import ErrorAlert from '@/components/ErrorAlert.vue'

const { submitting, fieldErrors, error, submit } = useForm()
const form = reactive({ name: '', email: '', password: '', organization: '', subdomain: '' })
const subdomainEdited = ref(false)

watch(() => form.organization, (name) => {
  if (subdomainEdited.value) return
  form.subdomain = name.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 40)
})

async function onSubmit() {
  const result = await submit(async () => {
    await authApi.csrf()
    return authApi.signup({
      user: { name: form.name, email: form.email, password: form.password },
      organization: { name: form.organization, subdomain: form.subdomain },
    })
  })
  if (result) window.location.href = urlOn(result.organization.subdomain, '/')
}
</script>

<template>
  <h1 class="title">Créer votre espace TyTrip</h1>
  <ErrorAlert :message="error" />
  <el-form label-position="top" @submit.prevent="onSubmit">
    <el-form-item label="Votre nom" :error="fieldErrors.name" required>
      <el-input v-model="form.name" autocomplete="name" />
    </el-form-item>
    <el-form-item label="Email professionnel" :error="fieldErrors.email" required>
      <el-input v-model="form.email" type="email" autocomplete="email" />
    </el-form-item>
    <el-form-item label="Mot de passe (12 caractères minimum)" :error="fieldErrors.password" required>
      <el-input v-model="form.password" type="password" autocomplete="new-password" show-password />
    </el-form-item>
    <el-form-item label="Nom de votre organisation" :error="fieldErrors.name" required>
      <el-input v-model="form.organization" />
    </el-form-item>
    <el-form-item label="Adresse de votre espace" :error="fieldErrors.subdomain" required>
      <el-input v-model="form.subdomain" @input="subdomainEdited = true">
        <template #append>.{{ appDomain() }}</template>
      </el-input>
    </el-form-item>
    <el-button type="primary" native-type="submit" :loading="submitting" class="full">Créer mon compte</el-button>
    <p class="links">Déjà inscrit ? <RouterLink to="/login">Se connecter</RouterLink></p>
  </el-form>
</template>

<style scoped>
.title { font-size: 18px; margin: 0 0 16px; }
.full { width: 100%; }
.links { margin-top: 16px; font-size: 14px; text-align: center; }
</style>
