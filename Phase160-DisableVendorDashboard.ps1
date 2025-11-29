# =====================================================================
# Phase160: Disable /dashboard/vendor (Clean Safe Version)
# =====================================================================

$ErrorActionPreference = "Stop"

# Safety: prevent system32 execution
$loc = (Get-Location).Path
if ($loc.ToLower().Contains("system32")) {
    Write-Host "ERROR: Do not run from system32. Navigate to the truvern folder." -ForegroundColor Red
    exit 1
}

Write-Host "=== Phase160: Disable /dashboard/vendor ===" -ForegroundColor Cyan

# Timestamp + backup directory
$ts = Get-Date -Format "yyyyMMdd-HHmmss"
$backupRoot = Join-Path $loc ("patch_backups\\phase160-" + $ts)
New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null

function BackupRemove {
    param([string]$p)

    if (Test-Path $p) {
        $name = Split-Path $p -Leaf
        $dest = Join-Path $backupRoot $name
        Write-Host ("Backing up " + $p + " -> " + $dest) -ForegroundColor Yellow
        Copy-Item $p $dest -Recurse -Force
        Remove-Item $p -Recurse -Force
        Write-Host ("Removed " + $p) -ForegroundColor Green
    } else {
        Write-Host ("Not found: " + $p) -ForegroundColor DarkYellow
    }
}

# Paths
$appVendor = Join-Path $loc "app\\dashboard\\vendor"
$pagesVendor = Join-Path $loc "pages\\dashboard\\vendor.tsx"
$compiledVendor = Join-Path $loc ".next\\server\\app\\dashboard\\vendor"

# Perform removals
BackupRemove $appVendor
BackupRemove $pagesVendor
BackupRemove $compiledVendor

# Clean build artifacts
if (Test-Path ".next") {
    Write-Host "Cleaning .next..." -ForegroundColor Yellow
    Remove-Item ".next" -Recurse -Force
}

if (Test-Path ".vercel\\output") {
    Write-Host "Cleaning .vercel/output..." -ForegroundColor Yellow
    Remove-Item ".vercel\\output" -Recurse -Force
}

# Rebuild the project
Write-Host "Running full rebuild..." -ForegroundColor Cyan

if (Get-Command pnpm -ErrorAction SilentlyContinue) {
    pnpm install --frozen-lockfile
    pnpm run build
} elseif (Get-Command npm -ErrorAction SilentlyContinue) {
    npm ci
    npm run build
} elseif (Get-Command yarn -ErrorAction SilentlyContinue) {
    yarn install --frozen-lockfile
    yarn build
} else {
    Write-Host "ERROR: No package manager installed." -ForegroundColor Red
    exit 1
}

# Run vercel build + deploy
if (Get-Command vercel -ErrorAction SilentlyContinue) {
    vercel build
    vercel deploy --prebuilt --prod
} else {
    Write-Host "WARNING: Vercel CLI not installed. Deploy not executed." -ForegroundColor Yellow
}

Write-Host "Phase160 complete." -ForegroundColor Green
