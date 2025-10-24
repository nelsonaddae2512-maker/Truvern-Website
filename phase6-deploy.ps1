param(
  [switch]$Prod
)

$ErrorActionPreference = "Stop"

# --- Always run from project root (this script's folder) ---
try {
  $scriptPath = $MyInvocation.MyCommand.Path
  if (-not $scriptPath) { $scriptPath = (Get-Location).Path; Write-Host "[WARN] Script path not found - defaulting to current folder" -ForegroundColor Yellow }
  $rootDir = Split-Path -Parent $scriptPath
  if (-not $rootDir) { $rootDir = (Get-Location).Path }
  Set-Location -Path $rootDir
  Write-Host "[OK] Working directory set to: $((Get-Location).Path)" -ForegroundColor Green
} catch {
  Write-Host "[ERR] Failed to set working directory: $($_.Exception.Message)" -ForegroundColor Red
  exit 1
}

# PowerShell 5.x compatibility for $PSStyle
if ($PSVersionTable.PSVersion.Major -ge 7) {
  $PSStyle.OutputRendering = 'Host'
}

Write-Host "`n=== Phase 6: Build & Deploy (Vercel) ===`n" -ForegroundColor Cyan

# --- Sanity checks ---
if (-not (Test-Path ".\package.json")) {
  Write-Host "[ERR] package.json not found in $(Get-Location). Ensure you're in the repo root." -ForegroundColor Red
  exit 1
}

# Pick package manager by lockfile
$pkgMgr = if (Test-Path ".\pnpm-lock.yaml") { "pnpm" } elseif (Test-Path ".\yarn.lock") { "yarn" } else { "npm" }
Write-Host "[OK] Package manager detected: $pkgMgr" -ForegroundColor Green

# Ensure Vercel CLI exists
if (-not (Get-Command vercel -ErrorAction SilentlyContinue)) {
  Write-Host "Installing Vercel CLI globally..." -ForegroundColor Yellow
  npm i -g vercel | Out-Null
}

# --- Vercel credentials ---
if (-not $env:VERCEL_TOKEN) {
  Write-Host "[ERR] VERCEL_TOKEN not set. In this session run: `$env:VERCEL_TOKEN = 'your-token-here'" -ForegroundColor Red
  exit 1
}

# --- Pull production env / framework settings ---
Write-Host "Pulling Vercel prod env..." -ForegroundColor Cyan
vercel pull --yes --environment=production --token $env:VERCEL_TOKEN | Out-Null

# --- Build (prebuilt artifact) ---
Write-Host "Creating production build artifact..." -ForegroundColor Cyan
vercel build --token $env:VERCEL_TOKEN

# --- Deploy prebuilt to Production (alias attaches automatically if configured) ---
Write-Host "Deploying prebuilt artifact to Production..." -ForegroundColor Cyan
$deployOutput = vercel deploy --prebuilt --prod --token $env:VERCEL_TOKEN
Write-Host $deployOutput

# Try to extract the deployment URL for convenience
$deployUrl = ($deployOutput | Select-String -Pattern "https?://[^\s]+" -AllMatches).Matches.Value | Select-Object -First 1
if ($deployUrl) {
  Write-Host "`n[OK] Deployment URL: $deployUrl" -ForegroundColor Green
  Write-Host "Open it to verify pages, then confirm the production alias (truvern.com) is attached." -ForegroundColor Green
}

Write-Host "`n=== Phase 6 Complete ===" -ForegroundColor Green
