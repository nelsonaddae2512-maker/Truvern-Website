$ErrorActionPreference = "Stop"
$here   = Split-Path -Parent $MyInvocation.MyCommand.Path
$script = Join-Path $here "neon-setup.ps1"

try {
  if (Test-Path $script) {
    & $script
  } else {
    Write-Host ("neon-setup.ps1 not found at: {0}" -f $script) -ForegroundColor Yellow
  }
}
catch {
  Write-Host "Script failed:" -ForegroundColor Red
  Write-Host $_.Exception.Message
  if ($_.InvocationInfo.PositionMessage) { Write-Host "`n$($_.InvocationInfo.PositionMessage)" }
}