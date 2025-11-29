# =====================================================================
# Phase163: Disable /assessment/results route to fix Vercel build
# =====================================================================

$ErrorActionPreference = "Stop"

# Safety: do not run from system32
$loc = (Get-Location).Path
if ($loc.ToLower().Contains("system32")) {
    Write-Host "ERROR: cd into your truvern folder first." -ForegroundColor Red
    exit 1
}

Write-Host "=== Phase163: Disable /assessment/results route ===" -ForegroundColor Cyan

# 1) Locate and rename the app/assessment/results folder if it exists
$assessmentDir = Join-Path (Get-Location) "app\assessment"
$resultsDir    = Join-Path $assessmentDir "results"

if (Test-Path $resultsDir) {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $newName   = "results_disabled_$timestamp"
    $newPath   = Join-Path $assessmentDir $newName

    Write-Host "Found: app\assessment\results" -ForegroundColor Yellow
    Write-Host "Renaming to: app\assessment\$newName" -ForegroundColor Yellow

    Rename-Item -Path $resultsDir -NewName $newName
} else {
    Write-Host "No app\assessment\results folder found (already disabled)." -ForegroundColor DarkGray
}

# 2) Clean .next and .vercel\output to avoid stale manifests
$pathsToClean = @(
    ".next",
    ".vercel\output"
)

foreach ($p in $pathsToClean) {
    if (Test-Path $p) {
        Write-Host ("Removing " + $p + "...") -ForegroundColor Yellow
        Remove-Item $p -Recurse -Force
    } else {
        Write-Host ("Not found (ok): " + $p) -ForegroundColor DarkGray
    }
}

# 3) Rebuild
Write-Host "Running pnpm install --frozen-lockfile..." -ForegroundColor Cyan
pnpm install --frozen-lockfile

Write-Host "Running pnpm run build..." -ForegroundColor Cyan
pnpm run build

Write-Host "Running vercel build..." -ForegroundColor Cyan
vercel build

Write-Host "Phase163 complete. /assessment/results has been disabled for now." -ForegroundColor Green
