import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'

export default defineConfig({
  plugins: [react()],
  server: {
    port: 3000,
    proxy: {
      // Проксируем все /api запросы на http://localhost:8000 (бэкенд)
      '/api': {
        target: 'http://localhost:8000',
        changeOrigin: true,
        secure: false,
        rewrite: (path) => path.replace(/^\/api/, '/api')
      },
      // Проксируем auth-dwh запросы
      '/auth-dwh': {
        target: 'http://localhost:8000',
        changeOrigin: true,
        secure: false
      }
    },
  },
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
})
