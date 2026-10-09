<script setup lang="ts">
import { reactive, ref } from 'vue'
import { organizationApi } from '@/api'
import { useAuthStore } from '@/stores/auth'
import { useForm } from '@/composables/useForm'
import { appDomain, currentSubdomain, hostKind, urlOn } from '@/utils/host'
import ErrorAlert from '@/components/ErrorAlert.vue'

const auth = useAuthStore()
const { submitting, fieldErrors, error, submit } = useForm()
const creating = ref(false)
const form = reactive({ name: '', subdomain: '' })
const notMember = hostKind() === 'tenant' && !auth.organization

function open(subdomain: string) {
  window.location.href = urlOn(subdomain, '/')
}

async function create() {
  const organization = await submit(() => organizationApi.create({ ...form }))
  if (organization) open(organization.subdomain)
}

async function logout() {
  await auth.logout()
  window.location.href = urlOn('app', '/login')
}
</script>

<template>
  <h1 class="title">Mes organisations</h1>
  <el-alert v-if="notMember" type="warning" :closable="false" show-icon class="mb"
    :title="`Vous n’avez pas accès à « ${currentSubdomain()} ».`" />

  <el-empty v-if="!auth.me?.organizations.length && !creating" description="Vous n’appartenez à aucune organisation." />
  <ul class="orgs">
    <li v-for="org in auth.me?.organizations" :key="org.id">
      <el-button class="org" @click="open(org.subdomain)">
        <span><strong>{{ org.name }}</strong><br><span class="muted">{{ org.subdomain }}.{{ appDomain() }} · {{ org.role }}</span></span>
      </el-button>
    </li>
  </ul>

  <el-button v-if="auth.me?.platform_admin" text type="primary" @click="open('admin')">Administration de la plateforme</el-button>

  <template v-if="creating">
    <ErrorAlert :message="error" />
    <el-form label-position="top" @submit.prevent="create">
      <el-form-item label="Nom de l’organisation" :error="fieldErrors.name" required><el-input v-model="form.name" /></el-form-item>
      <el-form-item label="Sous-domaine" :error="fieldErrors.subdomain" required>
        <el-input v-model="form.subdomain"><template #append>.{{ appDomain() }}</template></el-input>
      </el-form-item>
      <el-button type="primary" native-type="submit" :loading="submitting">Créer</el-button>
      <el-button @click="creating = false">Annuler</el-button>
    </el-form>
  </template>
  <div v-else class="footer">
    <el-button @click="creating = true">Créer une organisation</el-button>
    <el-button text @click="logout">Se déconnecter</el-button>
  </div>
</template>

<style scoped>
.title { font-size: 18px; margin: 0 0 16px; }
.orgs { list-style: none; padding: 0; margin: 0 0 16px; display: grid; gap: 8px; }
.org { width: 100%; height: auto; padding: 12px 16px; justify-content: flex-start; text-align: left; }
.footer { display: flex; justify-content: space-between; margin-top: 16px; }
.mb { margin-bottom: 16px; }
</style>
