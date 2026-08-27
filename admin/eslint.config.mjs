import { defineConfig, globalIgnores } from 'eslint/config';
import nextVitals from 'eslint-config-next/core-web-vitals';

export default defineConfig([
  ...nextVitals,
  globalIgnores(['.next/**', 'node_modules/**', 'next-env.d.ts']),
  {
    rules: {
      // Debounce efekti, kısa sorgularda eski sonuçları temizlemek için state günceller.
      'react-hooks/set-state-in-effect': 'off',
    },
  },
]);
