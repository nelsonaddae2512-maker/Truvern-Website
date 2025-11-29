# Phase90d-Runner.ps1 — keeps window open + logs output
$Host.UI.RawUI.WindowTitle = "Phase90d Runner"
$env:VERCEL_DEBUG = "1"
Start-Transcript -Path ".\phase90d-run.log" -Force | Out-Null
$ErrorActionPreference = 'Stop'
try {
  .\Phase90d-Patch2.ps1
  Write-Host "`n✔ Completed without fatal errors." -ForegroundColor Green
}
catch {
  Write-Host "`nFATAL:" -ForegroundColor Red
  $_ | Format-List * -Force
}
finally {
  Stop-Transcript | Out-Null
  Write-Host "`nLog saved to .\phase90d-run.log" -ForegroundColor Yellow
  Read-Host "`nPress ENTER to close"
}
