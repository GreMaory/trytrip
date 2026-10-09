import { fileURLToPath, URL } from 'node:url'
import { defineConfig, loadEnv } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '')

  return {
    plugins: [vue()],
    resolve: {
      alias: { '@': fileURLToPath(new URL('./src', import.meta.url)) },
    },
    server: {
      // Tenants are served on subdomains: acme.lvh.me, app.lvh.me...
      allowedHosts: [`.${env.VITE_APP_DOMAIN || 'lvh.me'}`],
      // Behind Traefik (docker compose) the browser talks to port 80.
      hmr: env.VITE_HMR_CLIENT_PORT ? { clientPort: Number(env.VITE_HMR_CLIENT_PORT) } : undefined,
      // Outside Docker, /api is proxied to Rails. The Host header is kept
      // (changeOrigin: false) because Rails resolves the tenant from it.
      proxy: {
        '/api': { target: env.VITE_API_PROXY || 'http://localhost:3000', changeOrigin: false },
      },
    },
    test: {
      environment: 'jsdom',
      globals: false,
    },
  }
})
