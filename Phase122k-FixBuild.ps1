Write-Host "=== Phase122k: Truvern Build Type Fix + Deploy ===" -ForegroundColor Cyan
$ErrorActionPreference = "Stop"
$root = "C:\Users\MR.NELSON\Downloads\truvern"
Set-Location $root

# 1️⃣ Patch the Next.js page.tsx typing issue
$pagePath = Join-Path $root "app\assessment\results\page.tsx"
if (Test-Path $pagePath) {
    Write-Host "Patching $pagePath ..." -ForegroundColor Yellow
    $code = Get-Content $pagePath -Raw

    # Replace any outdated prop or Promise typing with new PageProps structure
    $fixed = $code `
        -replace 'Promise<any>', '{ searchParams?: { [key: string]: string | string[] | undefined } }' `
        -replace 'PageProps', '{ searchParams?: { [key: string]: string | string[] | undefined } }'

    $fixed | Set-Content -Path $pagePath -Encoding utf8
    Write-Host "✅ Patched type definitions in results page." -ForegroundColor Green
} else {
    Write-Warning "Results page not found at $pagePath"
}

# 2️⃣ Ensure Tailwind and PostCSS are ready
Write-Host "Verifying CSS build configs..." -ForegroundColor Yellow
if (-not (Test-Path "$root\tailwind.config.ts")) {
    Write-Host "Creating tailwind.config.ts ..."
    @"
import type { Config } from 'tailwindcss'
const config: Config = {
  content: ['./app/**/*.{ts,tsx}', './components/**/*.{ts,tsx}'],
  theme: { extend: {} },
  plugins: [require('@tailwindcss/forms'), require('@tailwindcss/typography')],
}
export default config
"@ | Set-Content "$root\tailwind.config.ts"
}

if (-not (Test-Path "$root\postcss.config.cjs")) {
    Write-Host "Creating postcss.config.cjs ..."
    @"
module.exports = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
}
"@ | Set-Content "$root\postcss.config.cjs"
}

# 3️⃣ Re-run Prisma just to confirm schema consistency
Write-Host "Running Prisma generate..." -ForegroundColor Yellow
cmd /c "npx prisma generate" | Out-File -Append "$root\logs\phase122k-prisma.txt" -Encoding utf8

# 4️⃣ Build Next.js project
Write-Host "Running pnpm build..." -ForegroundColor Cyan
cmd /c "pnpm run build" | Out-File -Append "$root\logs\phase122k-build.txt" -Encoding utf8

# 5️⃣ Auto-deploy if build succeeds
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Build completed successfully! Deploying to Vercel..." -ForegroundColor Green
    cmd /c "vercel --prod --yes" | Out-File -Append "$root\logs\phase122k-deploy.txt" -Encoding utf8
    Write-Host "✅ Deployment complete. Verify at https://truvern.com" -ForegroundColor Green
} else {
    Write-Host "❌ Build failed. Inspect logs in /logs/phase122k-build.txt" -ForegroundColor Red
}

Write-Host "=== Phase122k complete ===" -ForegroundColor Cyan
Read-Host "Press Enter to close"
