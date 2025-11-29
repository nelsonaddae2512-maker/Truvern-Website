<# =====================================================================
 Phase136c-Deploy-Source.ps1
 Deploys the project to Vercel WITHOUT --prebuilt
 (Vercel will build in the cloud, avoiding Windows symlink issues)
 ===================================================================== #>

$ErrorActionPreference = "Stop"

Write-Host "`n=== Phase136c – Vercel Source Deploy ===`n" -ForegroundColor Cyan

# Ensure we are in the project root
if ($PWD.Path -match "System32") {
    Write-Host "[ERROR] Do NOT run from System32. cd into the project folder first." -ForegroundColor Red
    exit 1
}

if (-not (Test-Path "package.json")) {
    Write-Host "[ERROR] package.json not found – this is not the project root." -ForegroundColor Red
    exit 1
}

# Logs
if (-not (Test-Path ".\logs")) {
    New-Item -ItemType Directory -Path ".\logs" | Out-Null
}
$log = ".\logs\phase136c-" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".log"
Start-Transcript -Path $log -Force | Out-Null
Write-Host "[INFO] Logging to $log" -ForegroundColor DarkYellow

# Check Vercel CLI
if (-not (Get-Command "vercel" -ErrorAction SilentlyContinue)) {
    Write-Host "[ERROR] 'vercel' CLI not found. Install with:  npm i -g vercel" -ForegroundColor Red
    Stop-Transcript | Out-Null
    exit 1
}

Write-Host "[INFO] Deploying with: vercel deploy --prod --yes" -ForegroundColor Cyan

try {
    vercel deploy --prod --yes
    Write-Host "`n[OK] Source deploy command finished. Vercel is building in the cloud." -ForegroundColor Green
}
catch {
    Write-Host "`n[ERROR] Vercel deploy failed – see log: $log" -ForegroundColor Red
    Stop-Transcript | Out-Null
    exit 1
}

Write-Host "`n=== Phase136c Completed ===" -ForegroundColor Green
Stop-Transcript | Out-Null
