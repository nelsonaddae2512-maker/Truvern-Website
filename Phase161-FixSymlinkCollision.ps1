# =====================================================================
# Phase161: Fix Symlink Collision (trust/[slug] vs assessment/results)
# =====================================================================

$ErrorActionPreference = "Stop"

$loc = (Get-Location).Path
Write-Host "=== Phase161: Fix Symlink Collision ===" -ForegroundColor Cyan

# Safety: block system32
if ($loc.ToLower().Contains("system32")) {
    Write-Host "ERROR: Cannot run from system32." -ForegroundColor Red
    exit 1
}

# Paths
$vercelFunc = Join-Path $loc ".vercel\output\functions"
$trustSlug  = Join-Path $vercelFunc "trust\[slug].func"
$assessRes  = Join-Path $vercelFunc "assessment\results.func"

# Backup
$backup = Join-Path $loc ("patch_backups\phase161-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
New-Item -ItemType Directory -Path $backup -Force | Out-Null

function SafeRemove {
    param([string]$p)
    if (Test-Path $p) {
        $dest = Join-Path $backup (Split-Path $p -Leaf)
        Copy-Item $p $dest -Recurse -Force
        Remove-Item $p -Recurse -Force
        Write-Host ("Removed " + $p) -ForegroundColor Yellow
    }
}

Write-Host "Cleaning Vercel function collisions..." -ForegroundColor Cyan

SafeRemove $trustSlug
SafeRemove $assessRes

# Also clear entire functions folder
if (Test-Path $vercelFunc) {
    Write-Host "Clearing .vercel/output/functions..." -ForegroundColor Yellow
    Remove-Item $vercelFunc -Recurse -Force
}

# Clean .next + output
if (Test-Path ".next") {
    Remove-Item ".next" -Recurse -Force
}
if (Test-Path ".vercel\output") {
    Remove-Item ".vercel\output" -Recurse -Force
}

# Rebuild
Write-Host "Running rebuild..." -ForegroundColor Cyan
pnpm install --frozen-lockfile
pnpm run build

# Recreate prebuilt
vercel build
vercel deploy --prebuilt --prod

Write-Host "Phase161 complete." -ForegroundColor Green
