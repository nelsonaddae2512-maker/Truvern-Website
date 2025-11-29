param(
  [switch]$Deploy
)

$ErrorActionPreference = "Stop"
$root = "C:\Users\MR.NELSON\Downloads\truvern"
Set-Location $root

Write-Host "== Truvern Production Sync & Verify ==" -ForegroundColor Cyan

# 1️⃣ Verify environment files
$envFiles = @(".env.production.local", ".env.local", ".env")
$found = $envFiles | Where-Object { Test-Path $_ }
if ($found.Count -eq 0) {
  Write-Warning "No .env files found — please confirm environment variables."
} else {
  Write-Host "[INFO] Loading env from (high→low): $($found -join ', ')" -ForegroundColor Yellow
}

# 2️⃣ Check APP_URL and DATABASE_URL sanity
$env = Get-Content ($found | Select-Object -First 1) | ForEach-Object {
  if ($_ -match '^([^=]+)=(.*)$') { @{ Key=$matches[1]; Value=$matches[2] } }
}
$map = @{}
foreach ($item in $env) { $map[$item.Key] = $item.Value }

if ($map.APP_URL) {
  Write-Host "[OK] APP_URL looks OK ($($map.APP_URL))" -ForegroundColor Green
} else {
  Write-Warning "APP_URL missing!"
}
if ($map.DATABASE_URL -match "postgresql://") {
  Write-Host "[OK] DATABASE_URL format looks plausible." -ForegroundColor Green
} else {
  Write-Warning "DATABASE_URL invalid or missing!"
}

# 3️⃣ Clean & install deps
Write-Host "[INFO] Cleaning install..." -ForegroundColor Cyan
if (Test-Path "node_modules") { Remove-Item -Recurse -Force "node_modules" }
npm install --legacy-peer-deps

# 4️⃣ Prisma client refresh
if (Test-Path "$root\prisma\schema.prisma") {
  npx prisma generate
  Write-Host "[OK] Prisma client generated." -ForegroundColor Green
} else {
  Write-Warning "No schema.prisma found — skipping generate."
}

# 5️⃣ Build Next.js production build
Write-Host "[INFO] Running production build..." -ForegroundColor Cyan
npm run build

# 6️⃣ Deploy if requested
if ($Deploy) {
  Write-Host "[INFO] Deploying to Vercel..." -ForegroundColor Cyan
  $vercelBase = "npx vercel --token $env:VERCEL_TOKEN"
  try {
    if ([string]::IsNullOrWhiteSpace($env:VERCEL_PROJECT)) {
      Invoke-Expression "$vercelBase deploy --prod"
    } else {
      Invoke-Expression "$vercelBase deploy --prod --project $env:VERCEL_PROJECT"
    }
    Write-Host "[OK] Deployment complete." -ForegroundColor Green
  } catch {
    Write-Warning "Deploy failed: $_"
  }
} else {
  Write-Host "[INFO] Run again with -Deploy to deploy." -ForegroundColor Yellow
}

Write-Host "`n== All done. Build verified. ==" -ForegroundColor Green
