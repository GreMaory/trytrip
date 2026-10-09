<script setup lang="ts">
import { onMounted, ref, watch } from 'vue'
import { adminApi } from '@/api'
import type { Pagination } from '@/api/client'
import type { AuditEvent } from '@/api/types'
import { useLoader } from '@/composables/useForm'
import AuditTable from '@/components/AuditTable.vue'
import ErrorAlert from '@/components/ErrorAlert.vue'

const { loading, error, load } = useLoader()
const events = ref<AuditEvent[]>([])
const pagination = ref<Pagination | null>(null)
const page = ref(1)
const action = ref('')

async function fetch() {
  const result = await load(() => adminApi.auditEvents({ page: page.value, per_page: 50, action_name: action.value || undefined }))
  if (result) {
    events.value = result.items
    pagination.value = result.pagination
  }
}
watch(page, fetch)
onMounted(fetch)
</script>

<template>
  <div class="page">
    <div class="page-header"><h1>Audit de la plateforme</h1></div>
    <div class="toolbar">
      <el-input v-model="action" placeholder="Filtrer par action (ex. auth.login.failed)" clearable @change="page = 1; fetch()" aria-label="Action" />
    </div>
    <ErrorAlert :message="error" />
    <AuditTable :events="events" :loading="loading" show-tenant />
    <div class="pagination" v-if="pagination && pagination.total_pages > 1">
      <el-pagination v-model:current-page="page" :page-size="pagination.per_page" :total="pagination.total" layout="prev, pager, next" />
    </div>
  </div>
</template>
