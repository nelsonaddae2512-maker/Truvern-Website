$ErrorActionPreference = "Stop"

Write-Host "=== Phase158: Fix Evidence Lambda ===" -ForegroundColor Cyan

# Block running from system32
if (((Get-Location).Path).ToLower().Contains("windows\system32")) {
    Write-Host "ERROR: Do not run from system32." -ForegroundColor Red
    exit 1
}

$root = (Get-Location).Path
$evidenceBuildDir = Join-Path $root ".next\server\app\dashboard\evidence"

# Remove stale compiled output
if (Test-Path $evidenceBuildDir) {
    Write-Host "Removing stale lambda folder: $evidenceBuildDir" -ForegroundColor Yellow
    Remove-Item $evidenceBuildDir -Recurse -Force
    Write-Host "Stale lambda removed." -ForegroundColor Green
} else {
    Write-Host "No stale folder found. Continuing..." -ForegroundColor Yellow
}

# Clean previous builds
if (Test-Path ".next") {
    Remove-Item ".next" -Recurse -Force
}
if (Test-Path ".vercel\output") {
    Remove-Item ".vercel\output" -Recurse -Force
}

Write-Host "Cleaned .next and .vercel/output" -ForegroundColor Green

# Rebuild
if (Get-Command pnpm -ErrorAction SilentlyContinue) {
    pnpm install --frozen-lockfile
    pnpm run build
} elseif (Get-Command npm -ErrorAction SilentlyContinue) {
    npm ci
    npm run build
} elseif (Get-Command yarn -ErrorAction SilentlyContinue) {
    yarn install --frozen-lockfile
    yarn build
} else {
    Write-Host "ERROR: No package manager found." -ForegroundColor Red
    exit 1
}

# Deploy
if (Get-Command vercel -ErrorAction SilentlyContinue) {
    vercel build
    vercel deploy --prebuilt --prod
} else {
    Write-Host "ERROR: Vercel CLI not found." -ForegroundColor Red
    exit 1
}

Write-Host "Phase158 complete." -ForegroundColor Green
