<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import QRCode from 'qrcode'
import { authApi } from '@/api'
import { ApiError } from '@/api/client'
import type { DeviceSession } from '@/api/types'
import { useForm } from '@/composables/useForm'
import { useAuthStore } from '@/stores/auth'
import { formatDateTime } from '@/utils/format'
import ErrorAlert from '@/components/ErrorAlert.vue'

const auth = useAuthStore()
const profileForm = useForm()
const passwordForm = useForm()
const mfaForm = useForm()

const profile = reactive({ name: auth.me?.name ?? '', locale: auth.me?.locale ?? 'fr', time_zone: auth.me?.time_zone ?? 'Europe/Paris' })
const passwords = reactive({ current: '', next: '' })
const sessions = ref<DeviceSession[]>([])
const mfaSetup = ref<{ secret: string; qr: string } | null>(null)
const mfaCode = ref('')
const recoveryCodes = ref<string[]>([])

async function loadSessions() {
  sessions.value = await authApi.sessions()
}
onMounted(loadSessions)

async function saveProfile() {
  const ok = await profileForm.submit(async () => { await authApi.updateMe(profile); return true }, 'Profil mis à jour')
  if (ok) auth.fetchMe()
}

async function resendVerification() {
  await authApi.resendVerification()
  ElMessage.success('Email de vérification envoyé')
}

async function changePassword() {
  const ok = await passwordForm.submit(async () => { await authApi.changePassword(passwords.current, passwords.next); return true },
    'Mot de passe modifié, vos autres sessions ont été déconnectées')
  if (ok) {
    passwords.current = passwords.next = ''
    loadSessions()
  }
}

async function startMfa() {
  const setup = await mfaForm.submit(() => authApi.startMfa())
  if (setup) mfaSetup.value = { secret: setup.secret, qr: await QRCode.toDataURL(setup.provisioning_uri) }
}

async function confirmMfa() {
  const result = await mfaForm.submit(() => authApi.enableMfa(mfaCode.value), 'Double authentification activée')
  if (result) {
    recoveryCodes.value = result.recovery_codes
    mfaSetup.value = null
    mfaCode.value = ''
    auth.fetchMe()
  }
}

async function disableMfa() {
  try {
    const { value: password } = await ElMessageBox.prompt('Votre mot de passe', 'Désactiver la double authentification', { inputType: 'password' })
    const { value: code } = await ElMessageBox.prompt('Code de votre application ou code de récupération', 'Désactiver la double authentification')
    await authApi.disableMfa(password, code)
    ElMessage.success('Double authentification désactivée')
    auth.fetchMe()
  } catch (err) {
    if (err instanceof ApiError) ElMessage.error(err.message)
  }
}

async function regenerateCodes() {
  try {
    const { value: code } = await ElMessageBox.prompt('Code de votre application d’authentification', 'Nouveaux codes de récupération')
    recoveryCodes.value = (await authApi.regenerateRecoveryCodes(code)).recovery_codes
  } catch (err) {
    if (err instanceof ApiError) ElMessage.error(err.message)
  }
}

async function revoke(session: DeviceSession) {
  await authApi.revokeSession(session.id)
  loadSessions()
}

async function revokeOthers() {
  await authApi.revokeOtherSessions()
  ElMessage.success('Autres sessions déconnectées')
  loadSessions()
}
</script>

<template>
  <div class="page">
    <div class="page-header"><h1>Mon compte</h1></div>
    <div class="grid grid-2">
      <el-card shadow="never" header="Profil">
        <ErrorAlert :message="profileForm.error.value" />
        <el-form label-position="top" @submit.prevent="saveProfile">
          <el-form-item label="Email"><el-input :model-value="auth.me?.email" disabled /></el-form-item>
          <el-form-item label="Nom" :error="profileForm.fieldErrors.name"><el-input v-model="profile.name" /></el-form-item>
          <el-form-item label="Langue">
            <el-select v-model="profile.locale"><el-option label="Français" value="fr" /><el-option label="English" value="en" /></el-select>
          </el-form-item>
          <el-form-item label="Fuseau horaire" :error="profileForm.fieldErrors.time_zone"><el-input v-model="profile.time_zone" /></el-form-item>
          <el-button type="primary" native-type="submit" :loading="profileForm.submitting.value">Enregistrer</el-button>
          <el-button v-if="!auth.me?.email_verified" text @click="resendVerification">
            Renvoyer l’email de vérification
          </el-button>
        </el-form>
      </el-card>

      <el-card shadow="never" header="Mot de passe">
        <ErrorAlert :message="passwordForm.error.value" />
        <el-form label-position="top" @submit.prevent="changePassword">
          <el-form-item label="Mot de passe actuel" :error="passwordForm.fieldErrors.current_password">
            <el-input v-model="passwords.current" type="password" autocomplete="current-password" show-password />
          </el-form-item>
          <el-form-item label="Nouveau mot de passe (12 caractères minimum)" :error="passwordForm.fieldErrors.password">
            <el-input v-model="passwords.next" type="password" autocomplete="new-password" show-password />
          </el-form-item>
          <el-button type="primary" native-type="submit" :loading="passwordForm.submitting.value">Modifier</el-button>
        </el-form>
      </el-card>

      <el-card shadow="never" header="Double authentification (TOTP)">
        <ErrorAlert :message="mfaForm.error.value" />
        <template v-if="recoveryCodes.length">
          <el-alert type="warning" :closable="false" show-icon title="Conservez ces codes de récupération en lieu sûr : ils ne seront plus affichés." />
          <ul class="codes"><li v-for="code in recoveryCodes" :key="code"><code>{{ code }}</code></li></ul>
          <el-button @click="recoveryCodes = []">J’ai sauvegardé mes codes</el-button>
        </template>
        <template v-else-if="auth.me?.mfa_enabled">
          <p><el-tag type="success">Activée</el-tag> Un code vous est demandé à chaque connexion.</p>
          <el-button @click="regenerateCodes">Nouveaux codes de récupération</el-button>
          <el-button type="danger" plain @click="disableMfa">Désactiver</el-button>
        </template>
        <template v-else-if="mfaSetup">
          <p>Scannez ce QR code avec votre application (Google Authenticator, 1Password, Aegis…), puis saisissez le code affiché.</p>
          <img :src="mfaSetup.qr" alt="QR code de configuration de la double authentification" width="180" height="180" />
          <p class="muted">Clé manuelle : <code>{{ mfaSetup.secret }}</code></p>
          <el-form inline @submit.prevent="confirmMfa">
            <el-form-item label="Code"><el-input v-model="mfaCode" inputmode="numeric" autocomplete="one-time-code" maxlength="6" /></el-form-item>
            <el-button type="primary" native-type="submit" :loading="mfaForm.submitting.value">Activer</el-button>
          </el-form>
        </template>
        <template v-else>
          <p>Protégez votre compte avec un code à usage unique en plus de votre mot de passe.</p>
          <el-button type="primary" :loading="mfaForm.submitting.value" @click="startMfa">Configurer</el-button>
        </template>
      </el-card>

      <el-card shadow="never">
        <template #header>
          <div class="card-header"><span>Sessions actives</span><el-button size="small" @click="revokeOthers">Déconnecter les autres</el-button></div>
        </template>
        <el-table :data="sessions">
          <el-table-column label="Appareil" min-width="200">
            <template #default="{ row }"><span class="ua">{{ row.user_agent ?? 'Inconnu' }}</span> <el-tag v-if="row.current" size="small">Cette session</el-tag></template>
          </el-table-column>
          <el-table-column prop="ip_address" label="IP" width="130" />
          <el-table-column label="Dernière activité" width="170"><template #default="{ row }">{{ formatDateTime(row.last_seen_at ?? row.created_at) }}</template></el-table-column>
          <el-table-column width="110"><template #default="{ row }"><el-button v-if="!row.current" size="small" text type="danger" @click="revoke(row)">Révoquer</el-button></template></el-table-column>
        </el-table>
      </el-card>
    </div>
  </div>
</template>

<style scoped>
.codes { columns: 2; font-size: 15px; }
.card-header { display: flex; justify-content: space-between; align-items: center; }
.ua { font-size: 12px; }
</style>
