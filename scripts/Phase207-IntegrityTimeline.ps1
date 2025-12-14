# Phase207-IntegrityTimeline.ps1
# Truvern Integrity Timeline (SAFE ASCII VERSION)

$ErrorActionPreference = "Stop"

function Info { param($m) Write-Host $m -ForegroundColor Gray }
function Ok   { param($m) Write-Host "[OK]   $m" -ForegroundColor Green }
function Warn { param($m) Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Fail { param($m) Write-Host "[FAIL] $m" -ForegroundColor Red }

Write-Host ""
Write-Host "=== Phase207: Integrity Timeline ===" -ForegroundColor Cyan
Write-Host ""

$scriptsRoot = $PSScriptRoot
$projectRoot = Split-Path $scriptsRoot -Parent
Set-Location $projectRoot

Info "Project root: $projectRoot"

$integrityDir = Join-Path $scriptsRoot "logs\integrity"

if (-not (Test-Path $integrityDir)) {
    Fail "Integrity log directory not found: $integrityDir"
    exit 1
}

Ok "Integrity directory: $integrityDir"

# Get Phase203 output JSON files
$sealFiles = Get-ChildItem $integrityDir -Filter "Phase203-MasterSeal-*.json" |
    Sort-Object LastWriteTime -Descending

if (-not $sealFiles -or $sealFiles.Count -eq 0) {
    Fail "No Phase203 master seal files found."
    exit 1
}

$max = 20
$selected = $sealFiles | Select-Object -First $max

$lines = @()
$lines += "# Truvern Integrity Timeline"
$lines += ""
$lines += "Generated: $(Get-Date -Format o)"
$lines += ""
$lines += "| Run | CheckedAt | Status | Missing | SealFile |"
$lines += "| --- | ---------- | ------ | ------- | -------- |"

$run = 1

foreach ($f in $selected) {
    try {
        $raw = Get-Content $f.FullName -Raw
        $data = $raw | ConvertFrom-Json
    }
    catch {
        Warn "Failed to parse $($f.Name)"
        continue
    }

    $checked = $data.checkedAt
    if (-not $checked) {
        $checked = $f.LastWriteTimeUtc.ToString("o")
    }

    $status = $data.status
    if ($data.verified -eq $true) {
        $status = "pass"
    }

    $missingCount = 0
    if ($data.missingFiles) {
        $missingCount = @($data.missingFiles).Count
    }

    $sealRel = $f.FullName.Replace($projectRoot, "").Trim("\","/")

    $lines += "| $run | $checked | $status | $missingCount | $sealRel |"
    $run++
}

# Write markdown file
$timelineFile = Join-Path $integrityDir "integrity-timeline.md"
($lines -join "`r`n") | Set-Content -Path $timelineFile -Encoding UTF8

Ok "Timeline written to $timelineFile"

Write-Host "===== Phase207 COMPLETE - Integrity Timeline generated =====" -ForegroundColor Green
