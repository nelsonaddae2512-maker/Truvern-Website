# fix-react-next-build.ps1
$ErrorActionPreference = 'Stop'
Set-Location 'C:\Users\MR.NELSON\Downloads\truvern'

Write-Host "🧩 Repairing Truvern React + Next.js build..." -ForegroundColor Cyan

# 1️⃣ Clean environment
if (Test-Path '.next') { Remove-Item -Recurse -Force '.next' }
if (Test-Path 'node_modules') { Remove-Item -Recurse -Force 'node_modules' }
if (Test-Path 'package-lock.json') { Remove-Item -Force 'package-lock.json' }

# 2️⃣ Reinstall compatible versions
Write-Host "Installing compatible dependencies..." -ForegroundColor Yellow
npm install next@15.0.3 react@18.2.0 react-dom@18.2.0 autoprefixer postcss tailwindcss @tailwindcss/forms @tailwindcss/typography --legacy-peer-deps

# 3️⃣ Fix postcss.config.js (must be CommonJS)
@'
module.exports = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
};
'@ | Set-Content -Encoding UTF8 .\postcss.config.js

# 4️⃣ Fix next.config.mjs
@'
/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  experimental: {
    optimizeCss: true,
  },
};

export default nextConfig;
'@ | Set-Content -Encoding UTF8 .\next.config.mjs

# 5️⃣ Fix Tailwind configuration
@'
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
    "./pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: { extend: {} },
  plugins: [require("@tailwindcss/typography"), require("@tailwindcss/forms")],
};
'@ | Set-Content -Encoding UTF8 .\tailwind.config.js

# 6️⃣ Fix global styles
if (!(Test-Path "app")) { New-Item -ItemType Directory "app" | Out-Null }
@'
@tailwind base;
@tailwind components;
@tailwind utilities;

body {
  @apply bg-white text-gray-900 antialiased;
}
'@ | Set-Content -Encoding UTF8 .\app\globals.css

# 7️⃣ Local build
Write-Host "`n🏗️ Running build..." -ForegroundColor Yellow
npm run build

# 8️⃣ Deploy automatically to Vercel
Write-Host "`n🚀 Deploying to Vercel..." -ForegroundColor Cyan
$env:VERCEL_TOKEN = "8seJQdtzM5ryG6gtsyL0XWVZ"
npx vercel --prod --scope nelson-addaes-projects --yes

Write-Host "`n✅ Build + Deploy complete!" -ForegroundColor Green
Write-Host "Visit https://truvern.com and press Ctrl+F5 to hard refresh." -ForegroundColor Cyan
