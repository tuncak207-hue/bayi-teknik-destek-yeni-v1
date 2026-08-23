/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ['./src/**/*.{js,ts,jsx,tsx,mdx}'],
  theme: {
    extend: {
      colors: {
        brand: {
          DEFAULT: '#9B1C2E', // kurumsal, tonu düşürülmüş bordo — mobil ile aynı palet
          dark: '#6E1420',
          light: '#F5E1E4',
        },
        navy: {
          DEFAULT: '#0B1B2B',
          light: '#1D3A56',
        },
        ink: '#15202B',
      },
    },
  },
  plugins: [],
};
