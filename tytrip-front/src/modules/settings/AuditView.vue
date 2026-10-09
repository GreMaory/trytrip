<script setup lang="ts">
import { onMounted, ref, watch } from 'vue'
import { organizationApi } from '@/api'
import type { Pagination } from '@/api/client'
import type { AuditEvent } from '@/api/types'
import { useLoader } from '@/composables/useForm'
import AuditTable from '@/components/AuditTable.vue'
import ErrorAlert from '@/components/ErrorAlert.vue'

const { loading, error, load } = useLoader()
const events = ref<AuditEvent[]>([])
const pagination = ref<Pagination | null>(null)
const page = ref(1)

async function fetch() {
  const result = await load(() => organizationApi.auditEvents({ page: page.value, per_page: 50 }))
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
    <div class="page-header"><h1>Journal d’audit</h1></div>
    <ErrorAlert :message="error" />
    <AuditTable :events="events" :loading="loading" />
    <div class="pagination" v-if="pagination && pagination.total_pages > 1">
      <el-pagination v-model:current-page="page" :page-size="pagination.per_page" :total="pagination.total" layout="prev, pager, next" />
    </div>
  </div>
</template>
