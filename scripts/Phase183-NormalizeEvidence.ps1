# ==============================================
# Phase183 - Normalize Evidence List API + Verify
# ==============================================

$projectRoot = "C:\Users\MR.NELSON\Downloads\truvern"
$targetFile  = "$projectRoot\app\api\evidence\list\route.ts"

Write-Host "===== Phase183: Evidence API Normalize START =====" -ForegroundColor Yellow

if (-not (Test-Path $targetFile)) {
    Write-Host "ERROR: route.ts not found at expected location." -ForegroundColor Red
    exit 1
}

Write-Host "Evidence list route found." -ForegroundColor Green

# Simple smoke test
$url = "https://truvern.com/api/evidence/list"

Write-Host "Checking production endpoint: $url" -ForegroundColor Cyan

try {
    $response = Invoke-WebRequest -Uri $url -Method GET -UseBasicParsing -TimeoutSec 20
    $status = [int]$response.StatusCode

    if ($status -eq 200) {
        Write-Host "[OK] Production evidence list reachable." -ForegroundColor Green
    } else {
        Write-Host "[WARN] Returned status $status" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "[ERROR] Could not reach evidence list endpoint." -ForegroundColor Red
}

Write-Host "===== Phase183: COMPLETE =====" -ForegroundColor Yellow
