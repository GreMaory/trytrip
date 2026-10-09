<script setup lang="ts">
import { nextTick, ref, watch } from 'vue'

const props = defineProps<{ message: string | null }>()
const root = ref<{ $el: HTMLElement } | null>(null)

// Errors are shown above the form: bring them into view when they appear.
watch(() => props.message, async (message) => {
  if (!message) return
  await nextTick()
  root.value?.$el?.scrollIntoView?.({ behavior: 'smooth', block: 'center' })
})
</script>

<template>
  <el-alert v-if="message" ref="root" :title="message" type="error" show-icon :closable="false" class="error-alert" role="alert" />
</template>

<style scoped>
.error-alert { margin-bottom: 16px; }
</style>
