# Phase-ProdDB-EvidenceSync.ps1
# Sync Prisma schema (incl. Evidence) to PRODUCTION DB, then deploy + health check.

$ErrorActionPreference = "Stop"

$projectPath = "C:\Users\MR.NELSON\Downloads\truvern"

if (-not (Test-Path $projectPath)) {
    Write-Error "Project path not found: $projectPath"
    exit 1
}

Set-Location $projectPath
Write-Host "Working directory: $projectPath" -ForegroundColor Cyan

Write-Host ""
Write-Host "1) Pulling production env from Vercel..." -ForegroundColor Yellow
vercel pull --yes --environment=production
if ($LASTEXITCODE -ne 0) {
    Write-Error "vercel pull failed. Check Vercel auth / project link."
    exit 1
}

Write-Host ""
Write-Host "2) Running Prisma against PRODUCTION DB (NODE_ENV=production)..." -ForegroundColor Yellow

$env:NODE_ENV = "production"

Write-Host "   -> npx prisma generate" -ForegroundColor Yellow
npx prisma generate
if ($LASTEXITCODE -ne 0) {
    Write-Error "prisma generate failed."
    exit 1
}

Write-Host "   -> npx prisma db push" -ForegroundColor Yellow
npx prisma db push
if ($LASTEXITCODE -ne 0) {
    Write-Error "prisma db push failed against production DB."
    exit 1
}

Write-Host ""
Write-Host "3) Deploying via Phase-CLI-Deploy.ps1..." -ForegroundColor Yellow
.\Phase-CLI-Deploy.ps1
if ($LASTEXITCODE -ne 0) {
    Write-Error "Phase-CLI-Deploy.ps1 failed."
    exit 1
}

Write-Host ""
Write-Host "4) Running production health check..." -ForegroundColor Yellow
.\Phase-Prod-HealthCheck.ps1
if ($LASTEXITCODE -ne 0) {
    Write-Error "Phase-Prod-HealthCheck.ps1 failed."
    exit 1
}

Write-Host ""
Write-Host "✅ Production DB schema (incl. Evidence) synced, deployed & health-checked." -ForegroundColor Green
