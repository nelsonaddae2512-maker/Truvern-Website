<# 
    Phase132g-CloudDeploy.ps1
    -----------------------------------------
    - Runs from project directory
    - Ensures pnpm deps are installed (no frozen lockfile)
    - Uses `vercel --prod --yes` so the build runs in Vercel's cloud,
      avoiding Windows symlink issues from `vercel build`.
#>

param(
    [string]$ProjectDir = $PSScriptRoot
)

$ErrorActionPreference = "Stop"

Write-Host "=== Phase132g: Cloud Build + Deploy ===" -ForegroundColor Magenta

# 1) Normalise working directory
try {
    if (-not $ProjectDir -or $ProjectDir -eq "") {
        $ProjectDir = $PSScriptRoot
    }
    $projectPath = Resolve-Path $ProjectDir
} catch {
    Write-Host "[ERROR] Unable to resolve ProjectDir." -ForegroundColor Red
    exit 1
}

if ($PWD.Path -like "*System32*") {
    Set-Location $projectPath
} else {
    Set-Location $projectPath
}

Write-Host "[INFO] Working in: $((Get-Location).Path)" -ForegroundColor Cyan

# 2) Quick version check
Write-Host "[INFO] Node & Vercel versions:" -ForegroundColor Cyan
try { node -v } catch { Write-Host "[WARN] node not found." -ForegroundColor Yellow }
try { vercel --version } catch {
    Write-Host "[ERROR] vercel CLI not found. Run: npm i -g vercel" -ForegroundColor Red
    exit 1
}

Write-Host "[INFO] Checking Vercel login..." -ForegroundColor Cyan
try { vercel whoami } catch {
    Write-Host "[ERROR] Not logged into Vercel. Run 'vercel login' first." -ForegroundColor Red
    exit 1
}

# 3) Install deps (update lockfile)
Write-Host "`n[STEP] pnpm install --no-frozen-lockfile" -ForegroundColor Cyan
$pnpmCmd = Get-Command pnpm -ErrorAction SilentlyContinue
if (-not $pnpmCmd) {
    Write-Host "[ERROR] pnpm not installed. Run: npm i -g pnpm" -ForegroundColor Red
    exit 1
}

pnpm install --no-frozen-lockfile
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] pnpm install failed with exit code $LASTEXITCODE." -ForegroundColor Red
    exit 1
}

Write-Host "[INFO] Dependencies installed and lockfile synced." -ForegroundColor Green

# 4) Cloud build + deploy
Write-Host "`n[STEP] vercel --prod --yes (cloud build + deploy)" -ForegroundColor Cyan
vercel --prod --yes
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] vercel cloud deploy failed with exit code $LASTEXITCODE." -ForegroundColor Red
    exit 1
}

Write-Host "`n✅ Phase132g complete: Cloud build + deploy succeeded." -ForegroundColor Green
exit 0
