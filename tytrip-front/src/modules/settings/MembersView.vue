<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { organizationApi } from '@/api'
import { ApiError } from '@/api/client'
import type { Invitation, Membership, Role } from '@/api/types'
import { useForm, useLoader } from '@/composables/useForm'
import { useAuthStore } from '@/stores/auth'
import { formatDate } from '@/utils/format'
import ErrorAlert from '@/components/ErrorAlert.vue'

const auth = useAuthStore()
const { loading, error, load } = useLoader()
const inviteForm = useForm()
const members = ref<Membership[]>([])
const invitations = ref<Invitation[]>([])
const roles = ref<Role[]>([])
const inviteOpen = ref(false)
const invite = reactive({ email: '', role_id: undefined as number | undefined })
const canManage = auth.can('members.manage')

async function fetch() {
  await load(async () => {
    const [page, roleList, pending] = await Promise.all([
      organizationApi.memberships({ per_page: 100 }),
      organizationApi.roles(),
      canManage ? organizationApi.invitations() : Promise.resolve([]),
    ])
    members.value = page.items
    roles.value = roleList
    invitations.value = pending
  })
}
onMounted(fetch)

function isSelf(member: Membership) {
  return member.id === auth.organization?.membership_id
}

async function act(action: () => Promise<unknown>, success: string) {
  try {
    await action()
    ElMessage.success(success)
  } catch (err) {
    ElMessage.error(err instanceof ApiError ? err.message : 'Action impossible')
  }
  fetch()
}

function changeRole(member: Membership, roleId: number) {
  act(() => organizationApi.updateMembership(member.id, { role_id: roleId }), 'Rôle modifié')
}

function toggleStatus(member: Membership) {
  const status = member.status === 'active' ? 'suspended' : 'active'
  act(() => organizationApi.updateMembership(member.id, { status }), status === 'active' ? 'Accès réactivé' : 'Accès suspendu')
}

async function remove(member: Membership) {
  try {
    await ElMessageBox.confirm(`Retirer ${member.user.name} de l’organisation ?`, 'Retirer', { type: 'warning' })
  } catch { return }
  act(() => organizationApi.removeMembership(member.id), 'Membre retiré')
}

function revokeInvitation(invitation: Invitation) {
  act(() => organizationApi.revokeInvitation(invitation.id), 'Invitation révoquée')
}

async function sendInvitation() {
  const created = await inviteForm.submit(() => organizationApi.invite({ email: invite.email, role_id: invite.role_id! }), 'Invitation envoyée')
  if (created) {
    inviteOpen.value = false
    invite.email = ''
    fetch()
  }
}
</script>

<template>
  <div class="page">
    <div class="page-header">
      <h1>Membres</h1>
      <div class="actions"><el-button v-if="canManage" type="primary" @click="inviteOpen = true">Inviter</el-button></div>
    </div>
    <ErrorAlert :message="error" />

    <el-table v-loading="loading" :data="members">
      <el-table-column label="Nom" min-width="180"><template #default="{ row }">{{ row.user.name }} <el-tag v-if="isSelf(row)" size="small">Vous</el-tag></template></el-table-column>
      <el-table-column label="Email" min-width="200"><template #default="{ row }">{{ row.user.email }}</template></el-table-column>
      <el-table-column label="Rôle" width="220">
        <template #default="{ row }">
          <el-select v-if="canManage && !isSelf(row)" :model-value="row.role.id" size="small" :aria-label="`Rôle de ${row.user.name}`"
            @change="(id: number) => changeRole(row, id)">
            <el-option v-for="role in roles" :key="role.id" :label="role.name" :value="role.id" />
          </el-select>
          <span v-else>{{ row.role.name }}</span>
        </template>
      </el-table-column>
      <el-table-column label="Statut" width="110">
        <template #default="{ row }"><el-tag :type="row.status === 'active' ? 'success' : 'danger'">{{ row.status === 'active' ? 'Actif' : 'Suspendu' }}</el-tag></template>
      </el-table-column>
      <el-table-column v-if="canManage" width="200">
        <template #default="{ row }">
          <template v-if="!isSelf(row)">
            <el-button size="small" text @click="toggleStatus(row)">{{ row.status === 'active' ? 'Suspendre' : 'Réactiver' }}</el-button>
            <el-button size="small" text type="danger" @click="remove(row)">Retirer</el-button>
          </template>
        </template>
      </el-table-column>
    </el-table>

    <template v-if="canManage && invitations.length">
      <h2 class="subtitle">Invitations en attente</h2>
      <el-table :data="invitations">
        <el-table-column prop="email" label="Email" />
        <el-table-column label="Rôle"><template #default="{ row }">{{ row.role.name }}</template></el-table-column>
        <el-table-column label="Invité par"><template #default="{ row }">{{ row.invited_by.name }}</template></el-table-column>
        <el-table-column label="Expire le" width="140"><template #default="{ row }">{{ formatDate(row.expires_at) }}</template></el-table-column>
        <el-table-column width="110">
          <template #default="{ row }"><el-button size="small" text type="danger" @click="revokeInvitation(row)">Révoquer</el-button></template>
        </el-table-column>
      </el-table>
    </template>

    <el-dialog v-model="inviteOpen" title="Inviter un membre" width="460px">
      <ErrorAlert :message="inviteForm.error.value" />
      <el-form label-position="top" @submit.prevent="sendInvitation">
        <el-form-item label="Email" :error="inviteForm.fieldErrors.email" required><el-input v-model="invite.email" type="email" /></el-form-item>
        <el-form-item label="Rôle" :error="inviteForm.fieldErrors.role" required>
          <el-select v-model="invite.role_id" placeholder="Choisir un rôle">
            <el-option v-for="role in roles" :key="role.id" :label="role.name" :value="role.id" />
          </el-select>
        </el-form-item>
        <p class="muted">L’invitation est valable 7 jours. Vous ne pouvez attribuer que des droits dont vous disposez vous-même.</p>
      </el-form>
      <template #footer>
        <el-button @click="inviteOpen = false">Annuler</el-button>
        <el-button type="primary" :loading="inviteForm.submitting.value" @click="sendInvitation">Envoyer</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<style scoped>
.subtitle { font-size: 16px; margin: 32px 0 12px; }
</style>
