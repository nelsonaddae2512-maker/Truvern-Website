# Phase61-NoExit.ps1
$root = "C:\Users\MR.NELSON\Downloads\truvern"
Set-Location $root   # force project dir (never system32)
Write-Host "Launching Phase61-BoardReport.ps1 (no-exit)..." -ForegroundColor Cyan
try {
  & ".\Phase61-BoardReport.ps1" -Deploy:$true -SkipInstall:$false -SkipBuild:$false
} catch {
  Write-Host ("ERROR: " + $_.Exception.Message) -ForegroundColor Red
}
Read-Host "`nDone. Press Enter to close"
