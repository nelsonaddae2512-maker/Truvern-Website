param(
    [string]$ProjectDir = "C:\Users\MR.NELSON\Downloads\truvern"
)

# ==============================
# Phase165b: FINAL PROD DEPLOY (FIXED)
# ==============================

$ErrorActionPreference = "Stop"

function Write-Info($msg) {
    Write-Host "[INFO] $msg"
}

function Write-Warn($msg) {
    Write-Host "[WARN] $msg" -ForegroundColor Yellow
}

function Write-ErrMsg($msg) {
    Write-Host "[ERROR] $msg" -ForegroundColor Red
}

# Move to project directory
Set-Location $ProjectDir

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logDir = Join-Path $ProjectDir "logs"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
$logFile = Join-Path $logDir "Phase165b-FinalDeploy-Fix-$timestamp.log"

Write-Info "=== Phase165b: FINAL PROD DEPLOY (FIXED) ==="
Write-Info "Project dir: $ProjectDir"
Write-Info "Log file: $logFile"
Write-Host ""

# Tee all output to log file as well
Start-Transcript -Path $logFile -Append | Out-Null

try {
    # 1) Load .env.vercel into this PowerShell session
    $envFile = Join-Path $ProjectDir ".env.vercel"
    if (Test-Path $envFile) {
        Write-Info "Loading environment variables from .env.vercel ..."
        Get-Content $envFile | ForEach-Object {
            $line = $_.Trim()
            if ($line -eq "" -or $line.StartsWith("#")) { return }

            $parts = $line -split "=", 2
            if ($parts.Count -ne 2) { return }

            $key = $parts[0].Trim()
            $val = $parts[1]

            if ($key) {
                $env:$key = $val
            }
        }
    } else {
        Write-Warn ".env.vercel not found – using whatever env vars are already set."
    }

    Write-Host ""
    Write-Info "Key Vercel vars now in env:"
    Write-Host "  VERCEL_ORG_ID      = $($env:VERCEL_ORG_ID)"
    Write-Host "  VERCEL_PROJECT_ID  = $($env:VERCEL_PROJECT_ID)"
    Write-Host "  APP_URL            = $($env:APP_URL)"
    Write-Host ""

    # 2) Clean stale .next output (prevents EBUSY / locked file issues)
    $nextDir = Join-Path $ProjectDir ".next"
    if (Test-Path $nextDir) {
        Write-Info "Removing stale .next directory to avoid locked file issues..."
        Remove-Item $nextDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    # 3) Run pnpm build (local verification)
    Write-Host ""
    Write-Info "Running pnpm run build (local verification)..."
    $pnpm = "pnpm"
    $buildOutput = & $pnpm run build 2>&1
    $buildExit = $LASTEXITCODE

    $buildOutput | ForEach-Object { Write-Host $_ }

    if ($buildExit -ne 0) {
        Write-ErrMsg "pnpm run build failed with exit code $buildExit. Aborting deploy."
        throw "Local build failed."
    } else {
        Write-Info "pnpm run build completed successfully."
    }

    # 4) Run Vercel deploy -> PRODUCTION
    Write-Host ""
    Write-Info "Running Vercel deploy to PRODUCTION..."
    Write-Info "Command: vercel deploy --prod --confirm"

    $vercelOutput = & vercel deploy --prod --confirm 2>&1
    $deployExit   = $LASTEXITCODE

    $vercelOutput | ForEach-Object { Write-Host $_ }

    if ($deployExit -ne 0) {
        Write-ErrMsg "vercel deploy exited with code $deployExit."
        throw "Vercel deploy failed."
    } else {
        Write-Info "vercel deploy reported success."
    }

    Write-Host ""
    Write-Host "Phase165b complete. Production deploy command finished." -ForegroundColor Green
}
catch {
    Write-ErrMsg "Phase165b FAILED: $($_.Exception.Message)"
}
finally {
    Stop-Transcript | Out-Null
}
