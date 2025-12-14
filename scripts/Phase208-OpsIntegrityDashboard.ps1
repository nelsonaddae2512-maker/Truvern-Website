# Phase208-OpsIntegrityDashboard.ps1
# Wire master seal + integrity timeline into public ops health area

$ErrorActionPreference = "Stop"

function Info { param($m) Write-Host $m -ForegroundColor Gray }
function Ok   { param($m) Write-Host "[OK]   $m" -ForegroundColor Green }
function Warn { param($m) Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Fail { param($m) Write-Host "[FAIL] $m" -ForegroundColor Red }

Write-Host ""
Write-Host "=== Phase208: Ops Integrity Dashboard ===" -ForegroundColor Cyan
Write-Host ""

# Figure out project root
$scriptsRoot = $PSScriptRoot
$projectRoot = Split-Path $scriptsRoot -Parent
Set-Location $projectRoot

Info "Project root: $projectRoot"

# Paths
$integrityDir   = Join-Path $scriptsRoot "logs\integrity"
$timelineSource = Join-Path $integrityDir "integrity-timeline.md"

if (-not (Test-Path $integrityDir)) {
    Fail "Integrity log directory not found: $integrityDir"
    exit 1
}

if (-not (Test-Path $timelineSource)) {
    Warn "Timeline file not found: $timelineSource"
    Warn "Run Phase207-IntegrityTimeline.ps1 first."
    exit 1
}

Ok "Found timeline file: $timelineSource"

$publicOpsDir = Join-Path $projectRoot "public\ops\health"

if (-not (Test-Path $publicOpsDir)) {
    Info "Creating public ops health directory: $publicOpsDir"
    New-Item -ItemType Directory -Path $publicOpsDir -Force | Out-Null
}

# Copy timeline into public space
$timelineDest = Join-Path $publicOpsDir "integrity-timeline.md"
Copy-Item $timelineSource $timelineDest -Force

Ok "Copied integrity timeline to: $timelineDest"

# Check master seal JSON from Phase205
$sealJson = Join-Path $publicOpsDir "master-seal.json"
if (Test-Path $sealJson) {
    Ok "Master seal JSON present: $sealJson"
} else {
    Warn "Master seal JSON missing: $sealJson"
    Warn "Run Phase203 and Phase205 to refresh master seal."
}

Write-Host ""
Write-Host "===== Phase208 COMPLETE - Ops integrity assets ready for /ops/health =====" -ForegroundColor Green
