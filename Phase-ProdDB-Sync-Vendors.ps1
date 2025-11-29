<#
  Phase-ProdDB-Sync-Vendors.ps1

  Purpose:
    - Use the same DATABASE_URL that Vercel production uses
      (from .env.production.local)
    - Push the Prisma schema to that database (creates Vendor table, etc.)
    - Seed vendors via prisma/seed.js
    - Deploy via Vercel CLI (Phase-CLI-Deploy.ps1)
    - Run production health check (Phase-Prod-HealthCheck.ps1)

  Assumptions:
    - .env.production.local exists in the project root
    - There is a line DATABASE_URL=... in .env.production.local
    - prisma/seed.js exists and uses PrismaClient from @prisma/client
    - Phase-CLI-Deploy.ps1 and Phase-Prod-HealthCheck.ps1 exist
#>

$ErrorActionPreference = "Stop"

# 1) Always work from the project folder
$projectPath = "C:\Users\MR.NELSON\Downloads\truvern"

if (-not (Test-Path $projectPath)) {
    Write-Error "Project path not found: $projectPath"
    exit 1
}

Set-Location $projectPath
Write-Host "Working directory: $projectPath" -ForegroundColor Cyan

# 2) Read DATABASE_URL from .env.production.local
$prodEnvPath = Join-Path $projectPath ".env.production.local"

if (-not (Test-Path $prodEnvPath)) {
    Write-Error ".env.production.local not found at $prodEnvPath"
    exit 1
}

$prodDbLine = Get-Content $prodEnvPath | Where-Object { $_ -match '^DATABASE_URL=' }

if (-not $prodDbLine) {
    Write-Error "DATABASE_URL not found in .env.production.local"
    exit 1
}

$prefix = "DATABASE_URL="
$prodDbUrl = $prodDbLine.Substring($prefix.Length)

if ([string]::IsNullOrWhiteSpace($prodDbUrl)) {
    Write-Error "DATABASE_URL value in .env.production.local is empty"
    exit 1
}

# Set this session's DATABASE_URL so Prisma uses the PROD DB
$env:DATABASE_URL = $prodDbUrl

# Optional: show a masked preview for confirmation
$previewLen = [Math]::Min(60, $prodDbUrl.Length)
$preview = $prodDbUrl.Substring(0, $previewLen)
Write-Host "Using production DATABASE_URL (first characters):" -ForegroundColor Yellow
Write-Host "$preview..." -ForegroundColor DarkYellow

# 3) Ensure Prisma Client is generated
Write-Host ""
Write-Host "Running: npx prisma generate" -ForegroundColor Yellow
npx prisma generate
if ($LASTEXITCODE -ne 0) {
    Write-Error "prisma generate failed."
    exit 1
}
Write-Host "Prisma client generated." -ForegroundColor Green

# 4) Push schema to production DB (creates Vendor, Evidence, etc.)
Write-Host ""
Write-Host "Running: npx prisma db push --force-reset" -ForegroundColor Yellow
npx prisma db push --force-reset
if ($LASTEXITCODE -ne 0) {
    Write-Error "prisma db push failed."
    exit 1
}
Write-Host "Prisma schema pushed to production database." -ForegroundColor Green

# 5) Seed vendors into the same production DB
$seedFile = Join-Path $projectPath "prisma\seed.js"
if (-not (Test-Path $seedFile)) {
    Write-Error "Seed file not found: $seedFile"
    exit 1
}

Write-Host ""
Write-Host "Running vendor seed: node prisma/seed.js" -ForegroundColor Yellow
node prisma/seed.js
if ($LASTEXITCODE -ne 0) {
    Write-Error "Vendor seed (prisma/seed.js) failed."
    exit 1
}
Write-Host "Vendors seeded into production database." -ForegroundColor Green

# 6) Deploy with Vercel CLI (Phase-CLI-Deploy.ps1)
$deployScript = Join-Path $projectPath "Phase-CLI-Deploy.ps1"
if (-not (Test-Path $deployScript)) {
    Write-Error "Phase-CLI-Deploy.ps1 not found at $deployScript"
    exit 1
}

Write-Host ""
Write-Host "Running deployment script: Phase-CLI-Deploy.ps1" -ForegroundColor Yellow
.\Phase-CLI-Deploy.ps1
if ($LASTEXITCODE -ne 0) {
    Write-Error "Phase-CLI-Deploy.ps1 failed."
    exit 1
}
Write-Host "Deployment script completed." -ForegroundColor Green

# 7) Run production health check
$healthScript = Join-Path $projectPath "Phase-Prod-HealthCheck.ps1"
if (-not (Test-Path $healthScript)) {
    Write-Error "Phase-Prod-HealthCheck.ps1 not found at $healthScript"
    exit 1
}

Write-Host ""
Write-Host "Running production health check: Phase-Prod-HealthCheck.ps1" -ForegroundColor Yellow
.\Phase-Prod-HealthCheck.ps1
if ($LASTEXITCODE -ne 0) {
    Write-Error "Phase-Prod-HealthCheck.ps1 failed."
    exit 1
}

Write-Host ""
Write-Host "PROD DB synced, vendors seeded, deployment and health check complete." -ForegroundColor Green
