<script setup lang="ts">
import { ref } from 'vue'
import { useRoute } from 'vue-router'
import { authApi } from '@/api'
import { useForm } from '@/composables/useForm'
import ErrorAlert from '@/components/ErrorAlert.vue'

const route = useRoute()
const { submitting, fieldErrors, error, submit } = useForm()
const password = ref('')
const done = ref(false)
const token = typeof route.query.token === 'string' ? route.query.token : ''

async function onSubmit() {
  const ok = await submit(async () => {
    await authApi.csrf()
    await authApi.resetPassword(token, password.value)
    return true
  })
  if (ok) done.value = true
}
</script>

<template>
  <h1 class="title">Choisir un nouveau mot de passe</h1>
  <el-result v-if="done" icon="success" title="Mot de passe modifié" sub-title="Vous pouvez maintenant vous connecter.">
    <template #extra><el-button type="primary" @click="$router.push('/login')">Se connecter</el-button></template>
  </el-result>
  <el-alert v-else-if="!token" type="error" :closable="false" title="Lien invalide." />
  <template v-else>
    <ErrorAlert :message="error" />
    <el-form label-position="top" @submit.prevent="onSubmit">
      <el-form-item label="Nouveau mot de passe (12 caractères minimum)" :error="fieldErrors.password" required>
        <el-input v-model="password" type="password" autocomplete="new-password" show-password autofocus />
      </el-form-item>
      <el-button type="primary" native-type="submit" :loading="submitting" class="full">Enregistrer</el-button>
    </el-form>
  </template>
</template>

<style scoped>
.title { font-size: 18px; margin: 0 0 16px; }
.full { width: 100%; }
</style>
