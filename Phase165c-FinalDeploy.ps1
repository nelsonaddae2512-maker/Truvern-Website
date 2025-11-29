param(
    [string]$ProjectDir = "C:\Users\MR.NELSON\Downloads\truvern"
)

# ============================================
# Phase165c: FINAL PRODUCTION DEPLOY (SAFE)
# ============================================

$ErrorActionPreference = "Stop"

function Info($msg) { Write-Host "[INFO] $msg" }
function Warn($msg) { Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Err($msg)  { Write-Host "[ERROR] $msg" -ForegroundColor Red }

Set-Location $ProjectDir

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logDir = Join-Path $ProjectDir "logs"
if (!(Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
$logFile = Join-Path $logDir "Phase165c-FinalDeploy-$timestamp.log"

Start-Transcript -Path $logFile -Append | Out-Null

try {

    Info "=== Phase165c: Final Deployment ==="
    Info "Loading .env.vercel..."

    $envFile = Join-Path $ProjectDir ".env.vercel"

    if (Test-Path $envFile) {
        Get-Content $envFile | ForEach-Object {

            $line = $_.Trim()
            if ($line -eq "" -or $line.StartsWith("#")) { return }

            $parts = $line -split "=", 2
            if ($parts.Count -ne 2) { return }

            $key = $parts[0].Trim()
            $val = $parts[1].Trim()

            if ($key) {
                # PROPER WAY TO SET ENV VARIABLES
                [System.Environment]::SetEnvironmentVariable($key, $val, "Process")
            }
        }
    } else {
        Warn ".env.vercel was not found — continuing with current environment."
    }

    Info "Loaded Vercel ENV:"
    Write-Host "  VERCEL_ORG_ID     = $($env:VERCEL_ORG_ID)"
    Write-Host "  VERCEL_PROJECT_ID = $($env:VERCEL_PROJECT_ID)"
    Write-Host "  APP_URL           = $($env:APP_URL)"
    Write-Host ""

    # ======================
    # CLEAN STALE .next DIR
    # ======================
    $next = Join-Path $ProjectDir ".next"
    if (Test-Path $next) {
        Info "Removing stale .next directory..."
        Remove-Item $next -Recurse -Force -ErrorAction SilentlyContinue
    }

    # ======================
    # LOCAL BUILD VERIFY
    # ======================
    Info "Running pnpm run build..."
    $buildOut = & pnpm run build 2>&1
    $buildOut | ForEach-Object { Write-Host $_ }

    if ($LASTEXITCODE -ne 0) {
        Err "Local build FAILED — aborting deploy."
        throw "Local build failed."
    }

    Info "Local build completed successfully."

    # ======================
    # RUN VERCEL DEPLOY
    # ======================
    Info "Running Vercel deploy to PRODUCTION..."
    $vercelOut = & vercel deploy --prod --confirm 2>&1
    $vercelOut | ForEach-Object { Write-Host $_ }

    if ($LASTEXITCODE -ne 0) {
        Err "Vercel deploy FAILED."
        throw "Deploy failed."
    }

    Info "Vercel deploy SUCCESSFUL!"
    Info "Production should update now."

}
catch {
    Err "Phase165c FAILED: $($_.Exception.Message)"
}
finally {
    Stop-Transcript | Out-Null
}
