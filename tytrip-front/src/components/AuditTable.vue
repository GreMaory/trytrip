<script setup lang="ts">
import type { AuditEvent } from '@/api/types'
import { formatDateTime } from '@/utils/format'

defineProps<{ events: AuditEvent[]; loading?: boolean; showTenant?: boolean }>()
</script>

<template>
  <el-table v-loading="loading" :data="events" empty-text="Aucun événement">
    <el-table-column label="Date" width="180"><template #default="{ row }">{{ formatDateTime(row.created_at) }}</template></el-table-column>
    <el-table-column prop="action" label="Action" min-width="200" />
    <el-table-column label="Auteur" min-width="170"><template #default="{ row }">{{ row.actor?.name ?? '—' }}</template></el-table-column>
    <el-table-column v-if="showTenant" label="Org." width="80"><template #default="{ row }">{{ row.tenant_id ?? '—' }}</template></el-table-column>
    <el-table-column label="Objet" min-width="150"><template #default="{ row }">{{ row.subject_type ? `${row.subject_type.split('::').pop()} #${row.subject_id}` : '—' }}</template></el-table-column>
    <el-table-column label="Détails" min-width="220">
      <template #default="{ row }"><code class="meta">{{ Object.keys(row.metadata).length ? JSON.stringify(row.metadata) : '' }}</code></template>
    </el-table-column>
    <el-table-column prop="ip_address" label="IP" width="130" />
  </el-table>
</template>

<style scoped>
.meta { font-size: 12px; word-break: break-all; }
</style>
