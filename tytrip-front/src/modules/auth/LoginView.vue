<script setup lang="ts">
import { reactive, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { useForm } from '@/composables/useForm'
import ErrorAlert from '@/components/ErrorAlert.vue'

const auth = useAuthStore()
const route = useRoute()
const router = useRouter()
const { submitting, error, submit } = useForm()

const credentials = reactive({ email: '', password: '' })
const mfaStep = ref(false)
const code = ref('')

/** Only same-application paths: prevents open redirects through ?redirect= */
function safeRedirect(): string {
  const target = route.query.redirect
  return typeof target === 'string' && target.startsWith('/') && !target.startsWith('//') ? target : '/'
}

async function signIn() {
  const mfaRequired = await submit(() => auth.login(credentials.email, credentials.password))
  if (mfaRequired === true) mfaStep.value = true
  else if (mfaRequired === false) router.replace(safeRedirect())
}

async function verify() {
  const done = await submit(async () => {
    await auth.verifyMfa(code.value)
    return true
  })
  if (done) router.replace(safeRedirect())
}
</script>

<template>
  <h1 class="sr-only">Connexion</h1>
  <el-alert v-if="auth.sessionExpired" type="info" :closable="false" show-icon title="Votre session a expiré, reconnectez-vous." class="mb" />
  <ErrorAlert :message="error" />

  <el-form v-if="!mfaStep" label-position="top" @submit.prevent="signIn">
    <el-form-item label="Email" required>
      <el-input v-model="credentials.email" type="email" autocomplete="username" autofocus />
    </el-form-item>
    <el-form-item label="Mot de passe" required>
      <el-input v-model="credentials.password" type="password" autocomplete="current-password" show-password />
    </el-form-item>
    <el-button type="primary" native-type="submit" :loading="submitting" class="full">Se connecter</el-button>
    <div class="links">
      <RouterLink to="/forgot-password">Mot de passe oublié ?</RouterLink>
      <RouterLink to="/signup">Créer un compte</RouterLink>
    </div>
  </el-form>

  <el-form v-else label-position="top" @submit.prevent="verify">
    <p>Saisissez le code de votre application d’authentification, ou un code de récupération.</p>
    <el-form-item label="Code de vérification" required>
      <el-input v-model="code" autocomplete="one-time-code" inputmode="numeric" autofocus />
    </el-form-item>
    <el-button type="primary" native-type="submit" :loading="submitting" class="full">Vérifier</el-button>
  </el-form>
</template>

<style scoped>
.full { width: 100%; }
.links { display: flex; justify-content: space-between; margin-top: 16px; font-size: 14px; }
.mb { margin-bottom: 16px; }
</style>
