<# 
    Phase132e-DisableResultsRoute.ps1
    -----------------------------------------
    - Safely disables the problematic API route:
      app/api/assessment/results
    - Moves it to:
      app/api/assessment/results_disabled_backup_20251113
    - This stops Next/Vercel from trying to build the route that keeps
      becoming "results_disabled_20251113-001245" internally.
#>

param(
    [string]$ProjectDir = $PSScriptRoot
)

$ErrorActionPreference = "Stop"

Write-Host "=== Phase132e: Disable Assessment Results Route ===" -ForegroundColor Magenta

# Normalize working directory
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

$resultsDir = Join-Path $projectPath "app\api\assessment\results"
$backupDir  = Join-Path $projectPath "app\api\assessment\results_disabled_backup_20251113"

if (-not (Test-Path $resultsDir)) {
    Write-Host "[INFO] No app/api/assessment/results directory found. Nothing to disable." -ForegroundColor Cyan
    exit 0
}

if (Test-Path $backupDir) {
    Write-Host "[WARN] Backup directory already exists: $backupDir" -ForegroundColor Yellow
    Write-Host "[INFO] Assuming route already disabled." -ForegroundColor Cyan
    exit 0
}

Write-Host "[INFO] Moving $resultsDir -> $backupDir" -ForegroundColor Yellow
Move-Item -Path $resultsDir -Destination $backupDir

Write-Host "✅ Phase132e complete. Route app/api/assessment/results has been disabled for this build." -ForegroundColor Green

exit 0
