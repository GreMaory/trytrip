<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { organizationApi } from '@/api'
import { ApiError } from '@/api/client'
import type { Permission, Role } from '@/api/types'
import { useForm, useLoader } from '@/composables/useForm'
import { useAuthStore } from '@/stores/auth'
import { permissionGroups } from '@/utils/labels'
import ErrorAlert from '@/components/ErrorAlert.vue'

const auth = useAuthStore()
const { loading, error, load } = useLoader()
const roleForm = useForm()
const roles = ref<Role[]>([])
const permissions = ref<Permission[]>([])
const dialogOpen = ref(false)
const editing = ref<Role | null>(null)
const form = reactive({ name: '', description: '', permissions: [] as string[] })
const canManage = auth.can('roles.manage')

const grouped = computed(() => {
  const groups: Record<string, Permission[]> = {}
  for (const permission of permissions.value) (groups[permission.key.split('.')[0]!] ??= []).push(permission)
  return groups
})

async function fetch() {
  await load(async () => {
    ;[roles.value, permissions.value] = await Promise.all([organizationApi.roles(), organizationApi.permissions()])
  })
}
onMounted(fetch)

function open(role?: Role) {
  editing.value = role ?? null
  Object.assign(form, { name: role?.name ?? '', description: role?.description ?? '', permissions: [...(role?.permissions ?? [])] })
  roleForm.reset()
  dialogOpen.value = true
}

async function save() {
  const saved = await roleForm.submit(
    () => (editing.value ? organizationApi.updateRole(editing.value.id, form) : organizationApi.createRole(form)),
    'Rôle enregistré',
  )
  if (saved) {
    dialogOpen.value = false
    fetch()
  }
}

async function remove(role: Role) {
  try {
    await ElMessageBox.confirm(`Supprimer le rôle « ${role.name} » ?`, 'Supprimer', { type: 'warning' })
    await organizationApi.deleteRole(role.id)
    ElMessage.success('Rôle supprimé')
    fetch()
  } catch (err) {
    if (err instanceof ApiError) ElMessage.error(err.details.base?.[0] ?? err.message)
  }
}
</script>

<template>
  <div class="page">
    <div class="page-header">
      <h1>Rôles et permissions</h1>
      <div class="actions"><el-button v-if="canManage" type="primary" @click="open()">Nouveau rôle</el-button></div>
    </div>
    <ErrorAlert :message="error" />
    <el-table v-loading="loading" :data="roles">
      <el-table-column label="Rôle" min-width="180">
        <template #default="{ row }"><strong>{{ row.name }}</strong> <el-tag v-if="row.system" size="small" type="info">Système</el-tag><br><span class="muted">{{ row.description }}</span></template>
      </el-table-column>
      <el-table-column label="Permissions" min-width="300">
        <template #default="{ row }"><span class="muted">{{ row.permissions.length }} / {{ permissions.length }}</span></template>
      </el-table-column>
      <el-table-column prop="members_count" label="Membres" width="100" />
      <el-table-column v-if="canManage" width="180">
        <template #default="{ row }">
          <template v-if="!row.system">
            <el-button size="small" text @click="open(row)">Modifier</el-button>
            <el-button size="small" text type="danger" :disabled="row.members_count > 0" @click="remove(row)">Supprimer</el-button>
          </template>
          <el-button v-else size="small" text @click="open(row)">Voir</el-button>
        </template>
      </el-table-column>
    </el-table>

    <el-dialog v-model="dialogOpen" :title="editing ? editing.name : 'Nouveau rôle'" width="640px">
      <ErrorAlert :message="roleForm.error.value" />
      <el-form label-position="top" :disabled="editing?.system">
        <el-form-item label="Nom" :error="roleForm.fieldErrors.name" required><el-input v-model="form.name" /></el-form-item>
        <el-form-item label="Description"><el-input v-model="form.description" /></el-form-item>
        <el-form-item label="Permissions" :error="roleForm.fieldErrors.permissions">
          <el-checkbox-group v-model="form.permissions" class="permissions">
            <fieldset v-for="(items, group) in grouped" :key="group" class="group">
              <legend>{{ permissionGroups[group] ?? group }}</legend>
              <el-checkbox v-for="permission in items" :key="permission.key" :value="permission.key"
                :disabled="!auth.can(permission.key) && auth.organization?.role.key !== 'owner'">{{ permission.description }}</el-checkbox>
            </fieldset>
          </el-checkbox-group>
        </el-form-item>
        <p class="muted">Vous ne pouvez accorder que des permissions dont vous disposez vous-même.</p>
      </el-form>
      <template #footer>
        <el-button @click="dialogOpen = false">Fermer</el-button>
        <el-button v-if="!editing?.system" type="primary" :loading="roleForm.submitting.value" @click="save">Enregistrer</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<style scoped>
.permissions { display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: 8px; width: 100%; }
.group { border: 1px solid var(--el-border-color-lighter); border-radius: 6px; padding: 8px 12px; margin: 0; display: flex; flex-direction: column; }
.group legend { font-weight: 600; font-size: 13px; padding: 0 4px; }
</style>
