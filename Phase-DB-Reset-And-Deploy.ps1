<#
  Phase-DB-Reset-And-Deploy.ps1

  WARNING: This will drop and recreate the entire "public" schema
  in the database pointed to by DATABASE_URL in your .env file.
  All existing data will be lost.

  Steps:
    1) prisma migrate reset --force
    2) prisma generate
    3) Deploy via Phase-CLI-Deploy.ps1 (remote build on Vercel)
    4) Run Phase-Prod-HealthCheck.ps1
#>

$ErrorActionPreference = "Stop"

$projectPath = "C:\Users\MR.NELSON\Downloads\truvern"
Set-Location $projectPath

Write-Host "⚠️  About to reset the Prisma database (all data will be lost)..." -ForegroundColor Yellow
Write-Host "Using DATABASE_URL from .env in this folder." -ForegroundColor Yellow

# 1) Reset DB and reapply all migrations
Write-Host ""
Write-Host "🗄  Running: npx prisma migrate reset --force" -ForegroundColor Yellow
npx prisma migrate reset --force
if ($LASTEXITCODE -ne 0) {
    Write-Error "prisma migrate reset failed."
    exit 1
}

# 2) Regenerate Prisma Client
Write-Host ""
Write-Host "📦 Running: npx prisma generate" -ForegroundColor Yellow
npx prisma generate
if ($LASTEXITCODE -ne 0) {
    Write-Error "prisma generate failed."
    exit 1
}

Write-Host "✅ Prisma schema + database are now in sync." -ForegroundColor Green

# 3) Deploy using remote Vercel build
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
Write-Host "🎉 DB reset + deploy + health check complete." -ForegroundColor Green
