<#
  Phase-VendorSeed-And-Deploy-Simple.ps1

  Assumes:
    - prisma/seed.ts already exists (you created it manually)
    - package.json has: "prisma": { "seed": "ts-node prisma/seed.ts" }
    - Phase-CLI-Deploy.ps1 and Phase-Prod-HealthCheck.ps1 already exist
#>

$ErrorActionPreference = "Stop"

$projectPath = "C:\Users\MR.NELSON\Downloads\truvern"
Set-Location $projectPath

Write-Host "📁 Working directory set to: $projectPath" -ForegroundColor Cyan

# 1) Ensure dev deps for TypeScript seed
Write-Host "📦 Ensuring ts-node + typescript are installed..." -ForegroundColor Yellow
npm install -D ts-node typescript @types/node

# 2) Run Prisma seed
Write-Host "🌱 Running: npx prisma db seed" -ForegroundColor Yellow
npx prisma db seed
if ($LASTEXITCODE -ne 0) {
    Write-Error "Prisma db seed failed."
    exit 1
}
Write-Host "✅ Prisma seed completed." -ForegroundColor Green

# 3) Deploy (remote build on Vercel)
Write-Host ""
Write-Host "🚀 Deploying via Phase-CLI-Deploy.ps1..." -ForegroundColor Yellow
.\Phase-CLI-Deploy.ps1
if ($LASTEXITCODE -ne 0) {
    Write-Error "Phase-CLI-Deploy.ps1 failed."
    exit 1
}

# 4) Run production health check
Write-Host ""
Write-Host "🩺 Running Phase-Prod-HealthCheck.ps1..." -ForegroundColor Yellow
.\Phase-Prod-HealthCheck.ps1
if ($LASTEXITCODE -ne 0) {
    Write-Error "Phase-Prod-HealthCheck.ps1 failed."
    exit 1
}

Write-Host ""
Write-Host "🎉 Vendor seed + deploy + health check COMPLETE." -ForegroundColor Green
