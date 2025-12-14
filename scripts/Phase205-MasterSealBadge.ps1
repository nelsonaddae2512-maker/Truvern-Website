<# 
  Phase205-MasterSealBadge.ps1

  - Reads latest Phase204 verification JSON
  - Produces a compact health badge JSON at:
      public/ops/health/master-seal-badge.json

  Shape:

  {
    "check": "master-seal",
    "mode": "hybrid",
    "status": "pass" | "fail",
    "verified": true | false,
    "checkedAt": "...",
    "storedSeal": "...",
    "currentSeal": "...",
    "changed": 0,
    "new": 0,
    "missing": 0
  }
#>

param(
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot ".."))
)

function Write-Info($msg) { Write-Host "[INFO] $msg" -ForegroundColor Gray }
function Write-Ok($msg)   { Write-Host "[OK]   $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Fail($msg) { Write-Host "[FAIL] $msg" -ForegroundColor Red }

Write-Host "=== Phase205: Master Seal Health Badge ===" -ForegroundColor Cyan
Write-Info "Project root: $Root"

$integrityDir = Join-Path $PSScriptRoot "logs\integrity"

if (-not (Test-Path $integrityDir)) {
    Write-Fail "Integrity logs directory not found: $integrityDir"
    exit 1
}

$latestVerify = Get-ChildItem -Path $integrityDir -Filter "Phase204-MasterSealVerify-*.json" |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if (-not $latestVerify) {
    Write-Fail "No Phase204 verification JSON found in $integrityDir"
    exit 1
}

Write-Info ("Using verification file: " + $latestVerify.FullName)

try {
    $v = Get-Content -Path $latestVerify.FullName -Raw | ConvertFrom-Json
} catch {
    Write-Fail "Failed to parse verification JSON: $($_.Exception.Message)"
    exit 1
}

$ok = $false
if ($v -and $v.ok -eq $true) { $ok = $true }

$changedCount = 0
$newCount     = 0
$missingCount = 0

if ($v.changedFiles) { $changedCount = @($v.changedFiles).Count }
if ($v.newFiles)     { $newCount     = @($v.newFiles).Count }
if ($v.missingFiles) { $missingCount = @($v.missingFiles).Count }

$badge = [pscustomobject]@{
    check       = "master-seal"
    mode        = "hybrid"
    status      = (if ($ok) { "pass" } else { "fail" })
    verified    = [bool]$ok
    checkedAt   = $v.checkedAt
    storedSeal  = $v.storedSeal
    currentSeal = $v.currentSeal
    changed     = $changedCount
    new         = $newCount
    missing     = $missingCount
}

$healthDir = Join-Path $Root "public\ops\health"
if (-not (Test-Path $healthDir)) {
    New-Item -Path $healthDir -ItemType Directory -Force | Out-Null
}

$healthFile = Join-Path $healthDir "master-seal-badge.json"
$badge | ConvertTo-Json -Depth 4 | Set-Content -Path $healthFile -Encoding UTF8

Write-Ok ("Health badge JSON written to: " + $healthFile)
Write-Host "===== Phase205 COMPLETE - MASTER SEAL HEALTH BADGE =====" -ForegroundColor Green
