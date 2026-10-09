<template>
  <main class="auth-layout">
    <div class="auth-card">
      <div class="brand">TyTrip</div>
      <slot />
    </div>
  </main>
</template>

<style scoped>
.auth-layout { min-height: 100vh; display: flex; align-items: center; justify-content: center; padding: 24px; background: linear-gradient(135deg, #e8f0fe, #f5f7fa); }
.auth-card { width: 100%; max-width: 440px; background: #fff; border-radius: 12px; padding: 32px; box-shadow: 0 8px 32px rgba(0, 0, 0, 0.08); }
.brand { font-size: 26px; font-weight: 700; color: var(--el-color-primary); margin-bottom: 24px; text-align: center; }
</style>
