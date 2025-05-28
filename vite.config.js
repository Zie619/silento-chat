import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    port: 8080,
    host: '0.0.0.0',
    strictPort: true,
    allowedHosts: ['fd45fcd6-77b7-42f9-860c-00e1fd8677a0-00-1nkggw0kj4hph.spock.replit.dev'],
    hmr: {
      port: 8080,
      host: '0.0.0.0'
    },
    proxy: {
      '/api': {
        target: 'http://localhost:5000',
        changeOrigin: true,
        secure: false
      },
      '/ws': {
        target: 'ws://localhost:5000',
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