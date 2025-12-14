# Phase209-PublicStatusBadge.ps1
# Sanity check for public master seal status + badge

$ErrorActionPreference = "Stop"

function Info { param($m) Write-Host $m -ForegroundColor Gray }
function Ok   { param($m) Write-Host "[OK]   $m" -ForegroundColor Green }
function Warn { param($m) Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Fail { param($m) Write-Host "[FAIL] $m" -ForegroundColor Red }

Write-Host ""
Write-Host "=== Phase209: Public Status Badge ===" -ForegroundColor Cyan
Write-Host ""

# Figure out project root
$scriptsRoot = $PSScriptRoot
$projectRoot = Split-Path $scriptsRoot -Parent
Set-Location $projectRoot

Info "Project root: $projectRoot"

# Resolve base URL from APP_URL if present
$baseUrl = $env:APP_URL
if ([string]::IsNullOrWhiteSpace($baseUrl)) {
    $baseUrl = "https://truvern.com"
    Warn "APP_URL not set. Using default: $baseUrl"
} else {
    Ok "Using APP_URL from env: $baseUrl"
}

$opsDir   = Join-Path $projectRoot "public\ops\health"
$sealJson = Join-Path $opsDir "master-seal.json"

if (-not (Test-Path $opsDir)) {
    Warn "Ops health directory not found: $opsDir"
    Warn "Run Phase203, Phase205 and Phase208 first."
} else {
    Ok "Ops health directory present: $opsDir"
}

if (Test-Path $sealJson) {
    Ok "Master seal JSON present: $sealJson"
} else {
    Warn "Master seal JSON missing: $sealJson"
    Warn "Run Phase203-MasterIntegritySeal.ps1 and Phase205-MasterSealBadge.ps1."
}

Write-Host ""
Write-Host "Public status endpoints (once deployed):" -ForegroundColor Gray
Write-Host "  JSON : $baseUrl/api/status/master-seal" -ForegroundColor Cyan
Write-Host "  SVG  : $baseUrl/ops/health/master-seal-badge" -ForegroundColor Cyan
Write-Host ""
Write-Host "For local dev:" -ForegroundColor Gray
Write-Host "  JSON : http://localhost:3000/api/status/master-seal" -ForegroundColor DarkCyan
Write-Host "  SVG  : http://localhost:3000/ops/health/master-seal-badge" -ForegroundColor DarkCyan

Write-Host ""
Write-Host "===== Phase209 COMPLETE - Public status wiring ready (build and deploy next) =====" -ForegroundColor Green
