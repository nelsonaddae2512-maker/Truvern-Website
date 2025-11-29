# Phase62-NoExit.ps1 — keeps the window open no matter what
$ErrorActionPreference = "Stop"
try {
  # Always run from this file's folder
  $scriptPath = $MyInvocation.MyCommand.Path
  $root = if ($scriptPath) { Split-Path -Parent $scriptPath } else { (Get-Location).Path }
  Set-Location $root

  # Logging
  $logDir = Join-Path $root "logs"
  if (!(Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
  $log = Join-Path $logDir "Phase62-Wrapper.log"
  Start-Transcript -Path $log -Append -ErrorAction SilentlyContinue | Out-Null

  Write-Host "Launching Phase62-API-Bridge.ps1 (no-exit wrapper)..." -ForegroundColor Cyan
  # Forward any switches you want right here:
  $argsToBridge = @()  # e.g. @("-Deploy")
  & powershell -NoProfile -ExecutionPolicy Bypass -File ".\Phase62-API-Bridge.ps1" @argsToBridge
  if ($LASTEXITCODE -eq 0) {
    Write-Host "Phase62-API-Bridge.ps1 finished OK." -ForegroundColor Green
  } else {
    Write-Host "Phase62-API-Bridge.ps1 exited with code $LASTEXITCODE." -ForegroundColor Yellow
  }
}
catch {
  Write-Host ("ERROR: " + $_.Exception.Message) -ForegroundColor Red
}
finally {
  try { Stop-Transcript | Out-Null } catch {}
  Write-Host ""
  Write-Host "Wrapper done. Press Enter to close." -ForegroundColor DarkGray
  [void][System.Console]::ReadLine()
}
