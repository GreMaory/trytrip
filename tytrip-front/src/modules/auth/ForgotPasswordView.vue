<script setup lang="ts">
import { ref } from 'vue'
import { authApi } from '@/api'
import { useForm } from '@/composables/useForm'
import ErrorAlert from '@/components/ErrorAlert.vue'

const { submitting, error, submit } = useForm()
const email = ref('')
const sent = ref(false)

async function onSubmit() {
  const done = await submit(async () => {
    await authApi.csrf()
    await authApi.requestPasswordReset(email.value)
    return true
  })
  if (done) sent.value = true
}
</script>

<template>
  <h1 class="title">Mot de passe oublié</h1>
  <el-result v-if="sent" icon="success" title="Demande envoyée"
    sub-title="Si un compte existe pour cette adresse, vous recevrez un email avec un lien valable 30 minutes." />
  <template v-else>
    <ErrorAlert :message="error" />
    <el-form label-position="top" @submit.prevent="onSubmit">
      <el-form-item label="Email" required>
        <el-input v-model="email" type="email" autocomplete="email" autofocus />
      </el-form-item>
      <el-button type="primary" native-type="submit" :loading="submitting" class="full">Recevoir un lien</el-button>
    </el-form>
  </template>
  <p class="links"><RouterLink to="/login">Retour à la connexion</RouterLink></p>
</template>

<style scoped>
.title { font-size: 18px; margin: 0 0 16px; }
.full { width: 100%; }
.links { margin-top: 16px; font-size: 14px; text-align: center; }
</style>
