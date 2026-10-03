import tailwindcss from '@tailwindcss/vite';
import react from '@vitejs/plugin-react';
import path from 'path';
import {defineConfig} from 'vite';

export default defineConfig(() => {
  return {
    plugins: [react(), tailwindcss()],
    resolve: {
      alias: {
        '@': path.resolve(__dirname, '.'),
      },
    },
    server: {
      host: '0.0.0.0',
      port: 3000,
      // HMR is disabled in AI Studio via DISABLE_HMR env var.
      // Do not modify—file watching is disabled to prevent flickering during agent edits.
      hmr: process.env.DISABLE_HMR !== 'true',
      // Disable file watching when DISABLE_HMR is true to save CPU during agent edits.
      watch: process.env.DISABLE_HMR === 'true' ? null : {},
      proxy: {
        '/api/wallex': {
          target: 'https://api.wallex.ir/v1',
          changeOrigin: true,
          rewrite: (path) => path.replace(/^\/api\/wallex/, ''),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
          },
        },
        '/api/nobitex': {
          target: 'https://apiv2.nobitex.ir',
          changeOrigin: true,
          rewrite: (path) => path.replace(/^\/api\/nobitex/, ''),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
          },
        },
        '/api/ramzinex': {
          target: 'https://publicapi.ramzinex.com/exchange/api/v1.0/exchange',
          changeOrigin: true,
          rewrite: (path) => path.replace(/^\/api\/ramzinex/, ''),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
          },
        },
        '/api/bitbarg': {
          target: 'https://api.bitbarg.com/api/v1',
          changeOrigin: true,
          rewrite: (path) => path.replace(/^\/api\/bitbarg/, ''),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
          },
        },
        '/api/tetherland': {
          target: 'https://api.tetherland.com',
          changeOrigin: true,
          rewrite: (path) => path.replace(/^\/api\/tetherland/, ''),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
          },
        },
        '/api/tabdeal': {
          target: 'https://api1.tabdeal.org/r/api/v1',
          changeOrigin: true,
          rewrite: (path) => path.replace(/^\/api\/tabdeal/, ''),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
          },
        },
      },
    },
  };
});
