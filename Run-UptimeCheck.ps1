param([string]$BaseUrl = "https://truvern.com")

$here = $PSScriptRoot; if (-not $here) { $here = (Get-Location).Path }
Write-Host "Running from $here" -ForegroundColor Cyan

# Unblock in case it was downloaded
Unblock-File -Path .\monitoring\UptimeCheck.ps1 -ErrorAction SilentlyContinue

# Start a transcript so output is preserved
$dir = ".\logs\monitoring"; if (-not (Test-Path $dir)) { New-Item -Type Directory -Force -Path $dir | Out-Null }
$log = Join-Path $dir ("run-" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".log")
Start-Transcript -Path $log -Append | Out-Null

# Invoke checker (no Exit inside)
. .\monitoring\UptimeCheck.ps1 -BaseUrl $BaseUrl

Stop-Transcript | Out-Null
Write-Host ""
Write-Host "Log file: $log" -ForegroundColor Yellow
Write-Host "Tail: logs\monitoring\uptime.log" -ForegroundColor Yellow
Write-Host ""
Read-Host "Press ENTER to close this window"
