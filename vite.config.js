import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    port: 3000,
    host: '0.0.0.0',
    strictPort: true,
    hmr: {
      port: 3000,
      host: '0.0.0.0'
    },
    proxy: {
      '/api': {
        target: process.env.VITE_API_URL || 'https://silento-backend.onrender.com',
        changeOrigin: true,
        secure: true
      },
      '/health': {
        target: process.env.VITE_API_URL || 'https://silento-backend.onrender.com',
        changeOrigin: true,
        secure: true
      },
      '/ws': {
        target: (process.env.VITE_API_URL || 'https://silento-backend.onrender.com').replace('https:', 'wss:'),
        ws: true,
        changeOrigin: true
      }
    }
  },
  build: {
    outDir: 'dist'
  },
  define: {
    global: 'globalThis'
  }
})