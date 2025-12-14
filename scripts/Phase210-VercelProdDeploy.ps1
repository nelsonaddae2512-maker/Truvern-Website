# Phase210-VercelProdDeploy.ps1
# Safe, validated Vercel production deploy script

# Keep default behavior for most of the script
$ErrorActionPreference = "Stop"

function Log { param($m) Write-Host $m -ForegroundColor Gray }
function OK  { param($m) Write-Host "[OK] $m" -ForegroundColor Green }
function Warn { param($m) Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Fail { param($m) Write-Host "[FAIL] $m" -ForegroundColor Red }

Write-Host ""
Write-Host "=== Phase210: Vercel Production Deploy ===" -ForegroundColor Cyan
Write-Host ""

# Ensure root
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root
Log "Project root: $root"

# Prepare logging
$logDir = Join-Path $root "scripts\logs\deploy"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }

$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$logFile = Join-Path $logDir "Phase210-Deploy-$ts.txt"
Add-Content $logFile "Phase210 Vercel Deploy Started at $(Get-Date)"

function RunStep {
    param(
        [string]$title,
        [string]$cmd
    )

    Write-Host ""
    Log "---- $title ----"
    Add-Content $logFile "`n---- $title ----"
    Add-Content $logFile "Command: $cmd"

    # Temporarily allow non-terminating errors so prisma/npm/vercel
    # warnings on stderr don't blow up the script.
    $oldPref = $ErrorActionPreference
    $ErrorActionPreference = "Continue"

    $output = cmd.exe /c $cmd 2>&1

    # Restore preference
    $ErrorActionPreference = $oldPref

    foreach ($line in $output) {
        Add-Content $logFile $line
        Write-Host $line
    }

    if ($LASTEXITCODE -ne 0) {
        Fail "$title failed (exit $LASTEXITCODE)"
        Add-Content $logFile "Result: FAILED (exit $LASTEXITCODE)"
        throw "$title failed"
    } else {
        OK "$title succeeded"
        Add-Content $logFile "Result: OK"
    }
}

# Step 1: Prisma Validate
RunStep -title "Prisma Validate" -cmd "npx prisma validate"

# Step 2: Build
RunStep -title "npm run build" -cmd "npm run build"

# Step 3: Vercel Deploy
RunStep -title "Vercel Production Deploy" -cmd "npx vercel --prod --yes"

# Step 4: Remote health checks (only if APP_URL is set)
$baseUrl = $env:APP_URL
if ([string]::IsNullOrWhiteSpace($baseUrl)) {
    Warn "APP_URL not set: skipping health checks"
    Add-Content $logFile "APP_URL missing; health checks skipped."
}
else {
    Write-Host ""
    Log "Running remote health checks..."
    Add-Content $logFile "`nRemote Health Checks:"

    $urls = @(
        "$baseUrl/",
        "$baseUrl/trust-network",
        "$baseUrl/vendors",
        "$baseUrl/reports/board",
        "$baseUrl/api/vendors",
        "$baseUrl/api/evidence/list"
    )

    foreach ($u in $urls) {
        try {
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            $resp = Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop
            $sw.Stop()

            $ms = [int]$sw.ElapsedMilliseconds
            $status = $resp.StatusCode

            if ($status -ge 200 -and $status -lt 300) {
                OK "Health $u : $status (${ms}ms)"
                Add-Content $logFile "OK  $u : $status (${ms}ms)"
            } else {
                Warn "Health $u : $status (${ms}ms)"
                Add-Content $logFile "WARN  $u : $status (${ms}ms)"
            }
        }
        catch {
            Fail "Health failed $u : $($_.Exception.Message)"
            Add-Content $logFile "FAIL $u : $($_.Exception.Message)"
        }
    }
}

Add-Content $logFile "`nFinished at $(Get-Date)"

Write-Host ""
Write-Host "===== Phase210 COMPLETE =====" -ForegroundColor Green
Write-Host "Log saved to: $logFile" -ForegroundColor Gray
Write-Host ""
