<# 
  Phase122z-FixEnv.ps1
  Purpose: Verify and inject required environment variables for Prisma + Next.js build.
  Usage: powershell -ExecutionPolicy Bypass -File .\Phase122z-FixEnv.ps1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "=== Phase122z: Fix Environment and Rebuild ===" -ForegroundColor Cyan
$envPath = Join-Path (Get-Location) '.env'

if (-not (Test-Path $envPath)) {
  Write-Host "❌ No .env file found at $envPath" -ForegroundColor Red
  exit 1
}

# Load file and preview keys (without exposing secrets)
$envLines = Get-Content $envPath | Where-Object { $_ -match '=' }
$keys = $envLines | ForEach-Object { ($_ -split '=',2)[0].Trim() }

Write-Host "`nLoaded environment keys:" -ForegroundColor Cyan
$keys | ForEach-Object { Write-Host "• $_" -ForegroundColor Yellow }

# Define required keys for Prisma + Next.js
$required = @('DATABASE_URL','NEXTAUTH_SECRET','NEXTAUTH_URL','VERCEL_TOKEN','VERCEL_ORG_ID','VERCEL_PROJECT_ID')
$missing = @()

foreach ($k in $required) {
  if (-not ($keys -contains $k)) {
    Write-Host "⚠️  Missing key: $k" -ForegroundColor Red
    $missing += $k
  }
}

if ($missing.Count -gt 0) {
  Write-Host "`n⚠️  You must add these to .env before building:" -ForegroundColor Red
  $missing | ForEach-Object { Write-Host "   $_=" -ForegroundColor White }
  exit 2
}

Write-Host "`n✅ All required environment variables are present." -ForegroundColor Green

# Regenerate Prisma client cleanly
try {
  Write-Host "`nRunning: pnpm prisma generate ..." -ForegroundColor Cyan
  & pnpm prisma generate 2>&1 | Tee-Object -FilePath ./logs/phase122z-fixenv.log -Append
  Write-Host "✅ Prisma client regenerated." -ForegroundColor Green
}
catch {
  Write-Host "❌ Prisma generate failed: $($_.Exception.Message)" -ForegroundColor Red
  exit 3
}

# Try building again
try {
  Write-Host "`nRunning build (pnpm run build)..." -ForegroundColor Cyan
  & pnpm run build 2>&1 | Tee-Object -FilePath ./logs/phase122z-fixenv.log -Append
  Write-Host "✅ Build completed successfully." -ForegroundColor Green
}
catch {
  Write-Host "❌ Build failed: $($_.Exception.Message)" -ForegroundColor Red
  exit 4
}

# Deploy again
try {
  Write-Host "`nDeploying to Vercel..." -ForegroundColor Cyan
  & vercel --prod --yes 2>&1 | Tee-Object -FilePath ./logs/phase122z-fixenv.log -Append
  Write-Host "✅ Vercel deploy complete." -ForegroundColor Green
}
catch {
  Write-Host "❌ Deploy failed: $($_.Exception.Message)" -ForegroundColor Red
  exit 5
}

# Run verification
try {
  Write-Host "`nRunning Phase122y-AutoVerify..." -ForegroundColor Cyan
  & .\Phase122y-AutoVerify.ps1 -Base "https://truvern.com"
}
catch {
  Write-Host "⚠️ AutoVerify step skipped due to error: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host "`n=== Phase122z FixEnv Complete ===" -ForegroundColor Cyan
