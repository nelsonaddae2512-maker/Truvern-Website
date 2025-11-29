$ErrorActionPreference = "Stop"
Set-Location "C:\Users\MR.NELSON\Downloads\truvern"

Write-Host "Fixing Truvern Next.js build environment..." -ForegroundColor Cyan

# Remove conflicting lockfiles
if (Test-Path yarn.lock) { Remove-Item yarn.lock -Force }
if (Test-Path pnpm-lock.yaml) { Remove-Item pnpm-lock.yaml -Force }

# Clean build cache
if (Test-Path '.next') { Remove-Item -Recurse -Force '.next' }
if (Test-Path 'node_modules') { Remove-Item -Recurse -Force 'node_modules' }

# Install stable dependencies
npm install next@15.0.3 react react-dom autoprefixer postcss tailwindcss @tailwindcss/typography @tailwindcss/forms

# Fix postcss.config.js
@"
module.exports = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
};
"@ | Set-Content -Encoding UTF8 .\postcss.config.js

# Fix next.config.mjs
@"
/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  experimental: { optimizeCss: true }
};

export default nextConfig;
"@ | Set-Content -Encoding UTF8 .\next.config.mjs

# Tailwind configuration
@"
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './app/**/*.{js,ts,jsx,tsx,mdx}',
    './pages/**/*.{js,ts,jsx,tsx,mdx}',
    './components/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: { extend: {} },
  plugins: [require('@tailwindcss/typography'), require('@tailwindcss/forms')],
};
"@ | Set-Content -Encoding UTF8 .\tailwind.config.js

# Ensure globals.css exists
if (!(Test-Path 'app')) { New-Item -ItemType Directory 'app' | Out-Null }
@"
@tailwind base;
@tailwind components;
@tailwind utilities;

body { @apply bg-white text-gray-900 antialiased; }
"@ | Set-Content -Encoding UTF8 .\app\globals.css

# Reinstall everything and build
npm install
npm run build
