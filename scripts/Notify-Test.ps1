$root = "C:\Users\MR.NELSON\Downloads\truvern"
$notify = Join-Path $root "scripts\Notify.ps1"
$txt = "Truvern notification test at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')."
$res = & powershell -NoProfile -ExecutionPolicy Bypass -File $notify `
  -Subject "🔔 Truvern Notify Test" -TextBody $txt -SlackTitle "Notify Test"
Write-Host ("Notify test: slack={0} email={1}" -f $res.slack,$res.email) -ForegroundColor Yellow
