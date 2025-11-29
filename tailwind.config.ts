// tailwind.config.ts
import type { Config } from 'tailwindcss';

const config: Config = {
  content: [
    './app/**/*.{js,ts,jsx,tsx,mdx}',
    './components/**/*.{js,ts,jsx,tsx,mdx}',
    './pages/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        'truvern-bg': '#020617',       // slate-950-ish
        'truvern-card': '#020617',
        'truvern-accent': '#22c55e',   // Tailwind green-500
      },
      boxShadow: {
        'soft-card': '0 18px 45px rgba(15,23,42,0.75)',
      },
      borderRadius: {
        'xl-card': '1.5rem',
      },
    },
  },
  plugins: [],
};

export default config;
