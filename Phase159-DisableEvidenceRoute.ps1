<# =====================================================================
 Phase159-DisableEvidenceRoute.ps1
 Purpose:
   - Temporarily remove /dashboard/evidence from the app
   - Stop Vercel from expecting a lambda for that route
   - Rebuild and run vercel build + deploy
   - All changes are backed up under patch_backups
 ===================================================================== #>

$ErrorActionPreference = "Stop"

# Safety: do not run from system32
if (((Get-Location).Path).ToLower().Contains("windows\\system32")) {
    Write-Host "ERROR: Please run this from your truvern folder, not system32." -ForegroundColor Red
    exit 1
}

$root = (Get-Location).Path
$ts   = Get-Date -Format "yyyyMMdd-HHmmss"
$backupDir = Join-Path $root ("patch_backups\\phase159-" + $ts)

New-Item -ItemType Directory -Force -Path $backupDir | Out-Null

function BackupAndRemove {
    param([string]$TargetPath)

    if (Test-Path $TargetPath) {
        $leaf = Split-Path $TargetPath -Leaf
        $dest = Join-Path $backupDir $leaf
        Write-Host "Backing up $TargetPath -> $dest" -ForegroundColor Yellow
        Copy-Item $TargetPath $dest -Recurse -Force
        Write-Host "Removing $TargetPath from project..." -ForegroundColor Yellow
        Remove-Item $TargetPath -Recurse -Force
        Write-Host "Removed $TargetPath" -ForegroundColor Green
    } else {
        Write-Host "Nothing to remove at $TargetPath (not found)." -ForegroundColor DarkYellow
    }
}

Write-Host "=== Phase159: Disable /dashboard/evidence route ===" -ForegroundColor Cyan

# --------------------------------------------------------------------
# 1) Remove App Router route: app\dashboard\evidence
# --------------------------------------------------------------------

$appEvidenceDir = Join-Path $root "app\\dashboard\\evidence"
BackupAndRemove $appEvidenceDir

# --------------------------------------------------------------------
# 2) Remove any Pages route version: pages\dashboard\evidence.tsx
# --------------------------------------------------------------------

$pagesEvidenceFile = Join-Path $root "pages\\dashboard\\evidence.tsx"
BackupAndRemove $pagesEvidenceFile

# (Optional) also remove compiled .next server app folder for evidence
$compiledEvidenceDir = Join-Path $root ".next\\server\\app\\dashboard\\evidence"
if (Test-Path $compiledEvidenceDir) {
    Write-Host "Removing compiled folder $compiledEvidenceDir" -ForegroundColor Yellow
    Remove-Item $compiledEvidenceDir -Recurse -Force
}

# --------------------------------------------------------------------
# 3) Clean .next and .vercel/output fully
# --------------------------------------------------------------------

if (Test-Path ".next") {
    Write-Host "Cleaning .next..." -ForegroundColor Yellow
    Remove-Item ".next" -Recurse -Force
}
if (Test-Path ".vercel\\output") {
    Write-Host "Cleaning .vercel\\output..." -ForegroundColor Yellow
    Remove-Item ".vercel\\output" -Recurse -Force
}

Write-Host "Local build artifacts cleaned." -ForegroundColor Green

# --------------------------------------------------------------------
# 4) Rebuild Next.js
# --------------------------------------------------------------------

if (Get-Command pnpm -ErrorAction SilentlyContinue) {
    Write-Host "Running pnpm install + pnpm run build..." -ForegroundColor Yellow
    pnpm install --frozen-lockfile
    pnpm run build
} elseif (Get-Command npm -ErrorAction SilentlyContinue) {
    Write-Host "Running npm ci + npm run build..." -ForegroundColor Yellow
    npm ci
    npm run build
} elseif (Get-Command yarn -ErrorAction SilentlyContinue) {
    Write-Host "Running yarn install + yarn build..." -ForegroundColor Yellow
    yarn install --frozen-lockfile
    yarn build
} else {
    Write-Host "ERROR: No pnpm, npm, or yarn found in PATH." -ForegroundColor Red
    exit 1
}

# --------------------------------------------------------------------
# 5) Vercel build + deploy (if CLI present)
# --------------------------------------------------------------------

if (Get-Command vercel -ErrorAction SilentlyContinue) {
    Write-Host "Running vercel build..." -ForegroundColor Yellow
    vercel build

    Write-Host "Running vercel deploy --prebuilt --prod..." -ForegroundColor Yellow
    vercel deploy --prebuilt --prod
} else {
    Write-Host "WARNING: Vercel CLI not found; skipping deploy step." -ForegroundColor DarkYellow
}

Write-Host "Phase159 complete." -ForegroundColor Green
