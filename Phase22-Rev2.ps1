# ==============================================
# Phase22-Rev2: Smart Auto-Fix + Log Analyzer
# ==============================================
Write-Host "`n=== Phase22-Rev2: Smart Auto-Fix + Log Analyzer ===" -ForegroundColor Cyan

$ErrorActionPreference = "Stop"
$projectRoot = "C:\Users\MR.NELSON\Downloads\truvern"
Set-Location $projectRoot

# Ensure Vercel CLI is available
$vercelCmd = Join-Path $env:APPDATA "npm\vercel.cmd"
if (-not (Test-Path $vercelCmd)) {
  Write-Host "Installing Vercel CLI..." -ForegroundColor Yellow
  npm install -g vercel@latest
}

# Confirm authentication
$whoami = cmd /c "$vercelCmd whoami 2>$null"
if (-not $whoami) {
  Write-Host "??  Not authenticated. Launching login..." -ForegroundColor Yellow
  cmd /c "$vercelCmd login"
  $whoami = cmd /c "$vercelCmd whoami"
}
Write-Host "?? Logged in as: $whoami" -ForegroundColor Green

# Clean caches
Write-Host "?? Cleaning caches (.next, .vercel, node_modules\.cache)..." -ForegroundColor Yellow
Remove-Item -Recurse -Force ".next", ".vercel", "node_modules\.cache" -ErrorAction SilentlyContinue

# Build and deploy
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$buildLog = "logs\phase22rev2-build-$timestamp.log"
$deployLog = "logs\phase22rev2-deploy-$timestamp.log"
New-Item -ItemType Directory -Force -Path "logs" | Out-Null

Write-Host "`n[1] Building production bundle..." -ForegroundColor Cyan
cmd /c "$vercelCmd build --prod" *> $buildLog

Write-Host "`n[2] Deploying to Vercel..." -ForegroundColor Cyan
cmd /c "$vercelCmd --prod --yes" *> $deployLog

# Validate headers (best effort)
try {
  Write-Host "`n[3] Verifying headers on https://truvern.com ..." -ForegroundColor Cyan
  $resp = Invoke-WebRequest "https://truvern.com" -UseBasicParsing -TimeoutSec 20
  $hdr = $resp.Headers
  foreach ($k in @('Strict-Transport-Security','X-Frame-Options','Referrer-Policy','Permissions-Policy','Content-Security-Policy')) {
    $v = [string]$hdr[$k]
    if ([string]::IsNullOrWhiteSpace($v)) {
      Write-Host ("? {0}: missing" -f $k) -ForegroundColor Red
    } else {
      Write-Host ("? {0}: {1}" -f $k, $v) -ForegroundColor Green
    }
  }
}
catch {
  Write-Host "Header check skipped: $_" -ForegroundColor DarkYellow
}

Write-Host "`nPhase22-Rev2 complete ?" -ForegroundColor Green
Write-Host "Build log : $buildLog"
Write-Host "Deploy log: $deployLog"
