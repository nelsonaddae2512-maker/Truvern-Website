# =====================================================================
# Phase162: Clean Rebuild after EBUSY (resource busy) errors
# =====================================================================

$ErrorActionPreference = "Stop"

# Safety: don't run from system32
$loc = (Get-Location).Path
if ($loc.ToLower().Contains("system32")) {
    Write-Host "ERROR: Do not run from system32. cd into your truvern folder first." -ForegroundColor Red
    exit 1
}

Write-Host "=== Phase162: Clean Rebuild ===" -ForegroundColor Cyan

# 1) Kill any stray node processes (dev servers, previous builds, etc.)
Write-Host "Stopping stray Node.js processes..." -ForegroundColor Yellow
Get-Process node -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Host (" - Killing PID " + $_.Id) -ForegroundColor DarkYellow
    Stop-Process -Id $_.Id -Force
}

# 2) Clean build artifacts
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

# 3) Install and build
Write-Host "Running pnpm install --frozen-lockfile..." -ForegroundColor Cyan
pnpm install --frozen-lockfile

Write-Host "Running pnpm run build..." -ForegroundColor Cyan
pnpm run build

# 4) Prepare prebuilt output for Vercel
Write-Host "Running vercel build..." -ForegroundColor Cyan
vercel build

Write-Host "Phase162 complete." -ForegroundColor Green
