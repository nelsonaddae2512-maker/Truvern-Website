# =====================================================================
# Phase163b: Force-disable /assessment/results route
# =====================================================================

$ErrorActionPreference = "Stop"

# Safety: don't run from system32
$loc = (Get-Location).Path
if ($loc.ToLower().Contains("system32")) {
    Write-Host "ERROR: cd into your truvern folder first." -ForegroundColor Red
    exit 1
}

Write-Host "=== Phase163b: Force-disable /assessment/results ===" -ForegroundColor Cyan

# 1) Kill common processes that can lock the folder (node, VS Code)
$procsToKill = @("node", "code")

foreach ($name in $procsToKill) {
    $procs = Get-Process $name -ErrorAction SilentlyContinue
    if ($procs) {
        Write-Host "Stopping process: $name" -ForegroundColor Yellow
        $procs | ForEach-Object { Stop-Process -Id $_.Id -Force }
    } else {
        Write-Host "Process not running (ok): $name" -ForegroundColor DarkGray
    }
}

Start-Sleep -Seconds 2

# 2) Try to rename app/assessment/results
$assessmentDir = Join-Path (Get-Location) "app\assessment"
$resultsDir    = Join-Path $assessmentDir "results"

if (Test-Path $resultsDir) {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $newName   = "results_disabled_$timestamp"
    $newPath   = Join-Path $assessmentDir $newName

    Write-Host "Found: app\assessment\results" -ForegroundColor Yellow
    Write-Host "Renaming to: app\assessment\$newName" -ForegroundColor Yellow

    try {
        Rename-Item -Path $resultsDir -NewName $newName -ErrorAction Stop
        Write-Host "Rename successful." -ForegroundColor Green
    }
    catch {
        Write-Host ""
        Write-Host "Rename still failed because something has the folder open." -ForegroundColor Red
        Write-Host "Please close any Explorer windows or editors looking at:" -ForegroundColor Red
        Write-Host "  $resultsDir" -ForegroundColor Red
        Write-Host "Then run this script again: Phase163b-DisableAssessmentResults-Force.ps1" -ForegroundColor Yellow
        exit 1
    }
} else {
    Write-Host "No app\assessment\results folder found (already disabled)." -ForegroundColor DarkGray
}

# 3) Clean build artifacts
$pathsToClean = @(".next", ".vercel\output")

foreach ($p in $pathsToClean) {
    if (Test-Path $p) {
        Write-Host ("Removing " + $p + "...") -ForegroundColor Yellow
        Remove-Item $p -Recurse -Force
    } else {
        Write-Host ("Not found (ok): " + $p) -ForegroundColor DarkGray
    }
}

# 4) Rebuild and prebuild for Vercel
Write-Host "Running pnpm install --frozen-lockfile..." -ForegroundColor Cyan
pnpm install --frozen-lockfile

Write-Host "Running pnpm run build..." -ForegroundColor Cyan
pnpm run build

Write-Host "Running vercel build..." -ForegroundColor Cyan
vercel build

Write-Host "Phase163b complete. /assessment/results is disabled for now." -ForegroundColor Green
