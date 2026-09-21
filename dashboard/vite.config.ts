import { defineConfig } from 'vitest/config'
import react from '@vitejs/plugin-react'
import { fileURLToPath, URL } from 'node:url'

export default defineConfig({
  plugins: [react()],
  resolve: { alias: { '@': fileURLToPath(new URL('./src', import.meta.url)) } },
  server: { port: 5173, proxy: { '/api': process.env.API_PROXY_TARGET || 'http://127.0.0.1:8000', '/health': process.env.API_PROXY_TARGET || 'http://127.0.0.1:8000', '/ready': process.env.API_PROXY_TARGET || 'http://127.0.0.1:8000' } },
  test: { environment: 'jsdom', setupFiles: ['./src/test/setup.ts'], css: true, exclude: ['e2e/**', 'node_modules/**'] },
})
