# Phase90e-Runner.ps1 — wraps Phase90e-DowngradeLocal.ps1, never closes
$Host.UI.RawUI.WindowTitle = "Phase90e Runner"
$ErrorActionPreference = 'Stop'
$log = ".\phase90e-runner-$(Get-Date -Format yyyyMMdd-HHmmss).log"
Start-Transcript -Path $log -Force | Out-Null

try {
  if (-not (Test-Path ".\Phase90e-DowngradeLocal.ps1")) {
    throw "Phase90e-DowngradeLocal.ps1 not found in project root."
  }
  & .\Phase90e-DowngradeLocal.ps1
  Write-Host "`n✔ Completed without fatal errors." -ForegroundColor Green
}
catch {
  Write-Host "`nFATAL:" -ForegroundColor Red
  $_ | Format-List * -Force
}
finally {
  Stop-Transcript | Out-Null
  Write-Host "`nLog saved to $log" -ForegroundColor Yellow
  Read-Host "`nPress ENTER to close"
}
