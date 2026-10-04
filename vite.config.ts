import tailwindcss from '@tailwindcss/vite';
import react from '@vitejs/plugin-react';
import path from 'path';
import {defineConfig} from 'vite';

const createProxyOptions = (target: string, pathPrefix: string) => ({
  target,
  changeOrigin: true,
  secure: false,
  timeout: 8000,
  proxyTimeout: 8000,
  rewrite: (p: string) => p.replace(new RegExp(`^${pathPrefix}`), ''),
  headers: {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'application/json, text/plain, */*',
  },
  configure: (proxy: any) => {
    proxy.on('error', (err: any, _req: any, res: any) => {
      if (res && !res.headersSent) {
        res.writeHead(502, {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        });
        res.end(JSON.stringify({ error: 'Proxy upstream unavailable', details: err?.message || 'Connection reset' }));
      }
    });
  },
});

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
        '/api/wallex': createProxyOptions('https://api.wallex.ir/v1', '/api/wallex'),
        '/api/nobitex': createProxyOptions('https://apiv2.nobitex.ir', '/api/nobitex'),
        '/api/ramzinex': createProxyOptions('https://publicapi.ramzinex.com/exchange/api/v1.0/exchange', '/api/ramzinex'),
        '/api/bitbarg': createProxyOptions('https://api.bitbarg.com/api/v1', '/api/bitbarg'),
        '/api/tetherland': createProxyOptions('https://api.tetherland.com', '/api/tetherland'),
        '/api/tabdeal': createProxyOptions('https://api1.tabdeal.org/r/api/v1', '/api/tabdeal'),
        '/pairs': createProxyOptions('https://publicapi.ramzinex.com/exchange/api/v1.0/exchange/pairs', '/pairs'),
      },
    },
  };
});
