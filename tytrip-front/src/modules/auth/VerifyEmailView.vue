<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'
import { authApi } from '@/api'
import { ApiError } from '@/api/client'

const route = useRoute()
const state = ref<'loading' | 'done' | 'error'>('loading')

onMounted(async () => {
  const token = typeof route.query.token === 'string' ? route.query.token : ''
  try {
    await authApi.csrf()
    await authApi.verifyEmail(token)
    state.value = 'done'
  } catch (error) {
    state.value = 'error'
    if (!(error instanceof ApiError)) console.error(error)
  }
})
</script>

<template>
  <div v-loading="state === 'loading'" style="min-height: 120px">
    <el-result v-if="state === 'done'" icon="success" title="Adresse email confirmée" sub-title="Votre compte est activé.">
      <template #extra><el-button type="primary" @click="$router.push('/')">Continuer</el-button></template>
    </el-result>
    <el-result v-else-if="state === 'error'" icon="error" title="Lien invalide ou expiré"
      sub-title="Connectez-vous pour recevoir un nouveau lien de vérification.">
      <template #extra><el-button @click="$router.push('/login')">Se connecter</el-button></template>
    </el-result>
  </div>
</template>
