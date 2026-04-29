import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { resolve } from 'node:path';

// Aurora shell loads this module via dynamic `import()`. It supplies React
// and ReactDOM as imports, so we externalize them. Output is a single ESM
// entry at dist/main.js with a default-exported React component.
export default defineConfig({
  plugins: [react()],
  build: {
    target: 'esnext',
    outDir: 'dist',
    emptyOutDir: true,
    cssCodeSplit: false,
    sourcemap: true,
    lib: {
      entry: resolve(__dirname, 'src/main.tsx'),
      formats: ['es'],
      fileName: () => 'main.js',
    },
    rollupOptions: {
      external: ['react', 'react-dom', 'react/jsx-runtime'],
      output: {
        // Aurora shell maps these bare specifiers via importmap.
        globals: {},
        assetFileNames: (asset) =>
          asset.name === 'style.css' ? 'main.css' : 'assets/[name]-[hash][extname]',
      },
    },
  },
});
