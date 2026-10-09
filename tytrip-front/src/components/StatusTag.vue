<script setup lang="ts">
import type { ReservationStatus } from '@/api/types'
import { reservationStatusLabels, reservationStatusTypes } from '@/utils/labels'

defineProps<{ status: ReservationStatus }>()
</script>

<template>
  <el-tag :type="reservationStatusTypes[status]" disable-transitions>{{ reservationStatusLabels[status] }}</el-tag>
</template>
