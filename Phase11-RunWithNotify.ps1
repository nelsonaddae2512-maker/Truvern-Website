$ErrorActionPreference = "Continue"
$root = "C:\Users\MR.NELSON\Downloads\truvern"
Set-Location $root

$phase11 = Join-Path $root "Phase11-Final-AutoRollback.ps1"
if (-not (Test-Path $phase11)) {
  Write-Host "Phase 11 script not found: $phase11" -ForegroundColor Red
  exit 1
}

Write-Host "Running Phase 11..." -ForegroundColor Cyan
& powershell -NoProfile -ExecutionPolicy Bypass -File $phase11 | Tee-Object -Variable runLog | Out-Null

$repDir = Join-Path $root "reports\board"
$latest = Get-ChildItem $repDir -Filter "board-*.txt" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$txt = if ($latest) { Get-Content $latest.FullName -Raw } else { "No board report found." }

$failed  = ($txt -match "FAIL") -or ($txt -match "Rollback.*executed")
$subject = if ($failed) { "❗ Truvern Health/Deploy Alert" } else { "✅ Truvern Daily Health OK" }
$title   = if ($failed) { "Truvern Alert" } else { "Truvern Daily Health" }

Add-Type -AssemblyName System.Web -ErrorAction SilentlyContinue
if (-not ("System.Net.WebUtility" -as [type])) { Add-Type -AssemblyName System.Net.Http -ErrorAction SilentlyContinue }
$encoded = [System.Net.WebUtility]::HtmlEncode($txt)
$html = "<pre style='font-family:Consolas,Menlo,monospace'>" + $encoded + "</pre>"

$notify = Join-Path $root "scripts\Notify.ps1"
$res = & powershell -NoProfile -ExecutionPolicy Bypass -File $notify -Subject $subject -TextBody $txt -HtmlBody $html -SlackTitle $title

Write-Host ("Notify results: slack={0} email={1}" -f $res.slack,$res.email) -ForegroundColor Yellow
