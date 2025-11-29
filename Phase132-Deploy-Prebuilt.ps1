<# 
    Phase132-Deploy-Prebuilt.ps1
    -----------------------------------------
    - Ensures we are running from the project directory (not System32)
    - Pulls Vercel prod env (optional)
    - Fixes pnpm lockfile mismatch using `pnpm install --no-frozen-lockfile`
    - Runs `vercel build`
    - Deploys using `vercel deploy --prebuilt --prod --yes`
    - Uses SAFE transcript handling (never crashes)
#>

param(
    [string]$ProjectDir = $PSScriptRoot
)

$ErrorActionPreference = "Stop"

# -----------------------------
# 1) Normalise working directory
# -----------------------------
try {
    if (-not $ProjectDir -or $ProjectDir -eq "") {
        $ProjectDir = $PSScriptRoot
    }
    $projectPath = Resolve-Path -Path $ProjectDir
} catch {
    Write-Host "[ERROR] Unable to resolve ProjectDir '$ProjectDir'." -ForegroundColor Red
    exit 1
}

if ($PWD.Path -like "*Windows\System32*") {
    Write-Host "[INFO] Switching from System32 to $projectPath" -ForegroundColor Yellow
    Set-Location $projectPath
} else {
    Set-Location $projectPath
}

# -----------------------------
# 2) Setup logging (safe transcript)
# -----------------------------
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logDir = Join-Path $projectPath "logs"
$logFile = Join-Path $logDir "Phase132-Deploy-Prebuilt-$timestamp.log"

if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

# Safe transcript start
try {
    $hostType = $Host.GetType()
    $field = $hostType.GetField("_transcript", "NonPublic,Instance")
    if ($field) {
        $active = $field.GetValue($Host)
        if ($active) {
            try { Stop-Transcript | Out-Null } catch {}
        }
    }
} catch {}

try {
    Start-Transcript -Path $logFile -Force | Out-Null
    Write-Host "[INFO] Logging to $logFile" -ForegroundColor Green
} catch {
    Write-Host "[WARN] Transcript could not be started (OK to continue)" -ForegroundColor Yellow
}

# -----------------------------
# 3) Display versions
# -----------------------------
Write-Host "`n=== Phase132: Deploy Prebuilt Build ===`n" -ForegroundColor Magenta
Write-Host "[INFO] Node & Vercel versions:" -ForegroundColor Cyan

try { node -v } catch { Write-Host "[WARN] node not found. Build may fail." -ForegroundColor Yellow }
try { vercel --version } catch {
    Write-Host "[ERROR] Vercel CLI missing. Run: npm i -g vercel" -ForegroundColor Red
    exit 1
}

Write-Host "[INFO] Checking Vercel login..." -ForegroundColor Cyan
try { vercel whoami } catch {
    Write-Host "[ERROR] Not logged into Vercel. Run 'vercel login'." -ForegroundColor Red
    exit 1
}

# -----------------------------
# 4) Pull production env
# -----------------------------
Write-Host "`n============================================"
Write-Host "[STEP] vercel pull --environment=production"
Write-Host "============================================"

try {
    vercel pull --environment=production --yes
} catch {
    Write-Host "[WARN] vercel pull failed (non-critical)" -ForegroundColor Yellow
}

# -----------------------------
# 5) Fix pnpm lockfile mismatch
# -----------------------------
Write-Host "`n============================================"
Write-Host "[STEP] pnpm install --no-frozen-lockfile"
Write-Host "============================================"

$pnpmCmd = Get-Command pnpm -ErrorAction SilentlyContinue
if (-not $pnpmCmd) {
    Write-Host "[ERROR] pnpm not installed. Run: npm i -g pnpm" -ForegroundColor Red
    exit 1
}

pnpm install --no-frozen-lockfile
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] pnpm install failed. Lockfile may be corrupted." -ForegroundColor Red
    exit 1
}

Write-Host "[INFO] pnpm-lock.yaml synced." -ForegroundColor Green

# -----------------------------
# 6) Build with Vercel
# -----------------------------
Write-Host "`n============================================"
Write-Host "[STEP] vercel build"
Write-Host "============================================"

vercel build
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] vercel build failed." -ForegroundColor Red
    exit 1
}

Write-Host "[INFO] Build succeeded." -ForegroundColor Green

# -----------------------------
# 7) Deploy prebuilt output
# -----------------------------
Write-Host "`n============================================"
Write-Host "[STEP] vercel deploy --prebuilt --prod --yes"
Write-Host "============================================"

vercel deploy --prebuilt --prod --yes
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Deployment failed." -ForegroundColor Red
    exit 1
}

Write-Host "`n✅ Deployment COMPLETE!" -ForegroundColor Green
Write-Host "   - Lockfile updated" -ForegroundColor Green
Write-Host "   - Local build OK" -ForegroundColor Green
Write-Host "   - Prebuilt deploy OK" -ForegroundColor Green

try { Stop-Transcript | Out-Null } catch {}
exit 0
