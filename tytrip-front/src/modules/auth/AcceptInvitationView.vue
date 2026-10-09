<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import { useRoute } from 'vue-router'
import { invitationAcceptanceApi } from '@/api'
import { useForm, useLoader } from '@/composables/useForm'
import { urlOn } from '@/utils/host'
import ErrorAlert from '@/components/ErrorAlert.vue'

const route = useRoute()
const token = typeof route.query.token === 'string' ? route.query.token : ''
const { loading, error: loadError, load } = useLoader()
const { submitting, fieldErrors, error, submit } = useForm()
const invitation = ref<Awaited<ReturnType<typeof invitationAcceptanceApi.show>> | null>(null)
const form = reactive({ name: '', password: '' })

onMounted(async () => {
  invitation.value = (await load(() => invitationAcceptanceApi.show(token))) ?? null
})

async function accept() {
  const result = await submit(() =>
    invitationAcceptanceApi.accept({ token, password: form.password, name: invitation.value?.existing_account ? undefined : form.name }),
  )
  if (!result) return
  window.location.href = result.signed_in ? urlOn(result.organization.subdomain, '/') : urlOn('app', '/login')
}
</script>

<template>
  <div v-loading="loading">
    <el-alert v-if="loadError" type="error" :closable="false" title="Cette invitation est invalide ou a expiré." />
    <template v-else-if="invitation">
      <h1 class="title">Rejoindre {{ invitation.organization.name }}</h1>
      <p>Vous êtes invité(e) en tant que <strong>{{ invitation.role }}</strong> avec l’adresse <strong>{{ invitation.email }}</strong>.</p>
      <ErrorAlert :message="error" />
      <el-form label-position="top" @submit.prevent="accept">
        <el-form-item v-if="!invitation.existing_account" label="Votre nom" :error="fieldErrors.name" required>
          <el-input v-model="form.name" autocomplete="name" />
        </el-form-item>
        <el-form-item :label="invitation.existing_account ? 'Votre mot de passe TyTrip' : 'Choisissez un mot de passe (12 caractères minimum)'"
          :error="fieldErrors.password" required>
          <el-input v-model="form.password" type="password" show-password
            :autocomplete="invitation.existing_account ? 'current-password' : 'new-password'" />
        </el-form-item>
        <el-button type="primary" native-type="submit" :loading="submitting" class="full">Accepter l’invitation</el-button>
      </el-form>
    </template>
  </div>
</template>

<style scoped>
.title { font-size: 18px; margin: 0 0 8px; }
.full { width: 100%; }
</style>
