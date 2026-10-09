import { createApp } from 'vue'
import { createPinia } from 'pinia'
import ElementPlus from 'element-plus'
import fr from 'element-plus/es/locale/lang/fr'
import 'element-plus/dist/index.css'
import './assets/main.css'

import App from './App.vue'
import { createAppRouter } from './router'
import { setUnauthorizedHandler } from './api/client'
import { useAuthStore } from './stores/auth'

const app = createApp(App)
const pinia = createPinia()
const router = createAppRouter()

app.use(pinia)
app.use(router)
app.use(ElementPlus, { locale: fr })

// Expired or revoked session: back to the login page.
setUnauthorizedHandler(() => {
  const auth = useAuthStore()
  if (!auth.isAuthenticated) return
  auth.markSessionExpired()
  const current = router.currentRoute.value
  if (!current.meta.public) router.push({ name: 'login', query: { redirect: current.fullPath } })
})

app.mount('#app')
