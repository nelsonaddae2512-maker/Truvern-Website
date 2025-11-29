<#
  Phase-Prisma-DBFix-And-Deploy.ps1

  - Forces Neon DB schema to match prisma/schema.prisma
  - Runs prisma db seed (uses prisma/seed.ts)
  - Deploys via Phase-CLI-Deploy.ps1
  - Runs Phase-Prod-HealthCheck.ps1

  WARNING: --force-reset will DROP and recreate the public schema.
  Only use this because we know the DB is currently empty / test.
#>

$ErrorActionPreference = "Stop"

$projectPath = "C:\Users\MR.NELSON\Downloads\truvern"
Set-Location $projectPath

Write-Host "📁 Working directory set to: $projectPath" -ForegroundColor Cyan

# 1) Force DB schema to match prisma/schema.prisma (creates Vendor, Evidence, etc.)
Write-Host "🗄  Running: npx prisma db push --force-reset" -ForegroundColor Yellow
npx prisma db push --force-reset
if ($LASTEXITCODE -ne 0) {
    Write-Error "prisma db push failed."
    exit 1
}
Write-Host "✅ prisma db push completed; DB schema is now in sync." -ForegroundColor Green

# 2) Run seed (uses prisma/seed.ts with PrismaClient)
Write-Host ""
Write-Host "🌱 Running: npx prisma db seed" -ForegroundColor Yellow
npx prisma db seed
if ($LASTEXITCODE -ne 0) {
    Write-Error "Prisma db seed failed."
    exit 1
}
Write-Host "✅ Prisma seed completed; vendors inserted." -ForegroundColor Green

# 3) Deploy via remote Vercel build
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
Write-Host "🎉 DB fixed + seeded + deployed + health-checked." -ForegroundColor Green
