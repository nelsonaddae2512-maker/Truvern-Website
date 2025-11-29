$ErrorActionPreference = "Stop"
Set-Location "C:\Users\MR.NELSON\Downloads\truvern"

if (-not (Test-Path ".\Phase93-ClientNullGuard-Clean.ps1")) {
  Write-Host "Script Phase93-ClientNullGuard-Clean.ps1 not found in $(Get-Location)" -ForegroundColor Red
  Read-Host "Press Enter to close"
  exit
}

if (-not (Test-Path ".\logs")) { New-Item -ItemType Directory -Path ".\logs" | Out-Null }

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$log   = ".\logs\Phase93-run-$stamp.log"

Write-Host "Running Phase93 (logging to $log)..." -ForegroundColor Yellow
try {
  . ".\Phase93-ClientNullGuard-Clean.ps1" *>&1 | Tee-Object -FilePath $log
} catch {
  Write-Host ("ERROR: " + $_.Exception.Message) -ForegroundColor Red
} finally {
  Write-Host "`n---`nRun complete. Log saved to: $log" -ForegroundColor Cyan
  Read-Host "Press Enter to close" | Out-Null
}
