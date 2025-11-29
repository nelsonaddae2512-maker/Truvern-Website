# Phase74-Hotfix.ps1 — safely run Vercel via npx instead of npm shim
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Sec($t){ Write-Host "`n=== $t ===" -ForegroundColor Cyan }
function Ok($t){ Write-Host $t -ForegroundColor Green }

Sec "Removing bad Vercel shim"
$shim = "$env:APPDATA\npm\vercel.ps1"
if (Test-Path $shim) {
  Remove-Item $shim -Force
  Ok "Deleted $shim"
} else {
  Ok "No vercel.ps1 shim found"
}

Sec "Verifying correct Vercel path"
npm prefix -g | Out-Host
where.exe vercel | Out-Host

Sec "Running direct npx deploy"
npx vercel pull --environment=production --yes | Out-Host
$out = & npx vercel deploy --prod --yes 2>&1
$exit = $LASTEXITCODE
$out | Out-Host

if ($exit -ne 0) { throw "Vercel deploy failed ($exit)" }

$prod = ($out | Select-String -Pattern "https://[^ ]+\.vercel\.app").Matches.Value | Select-Object -Last 1
if (-not $prod) { $prod = "https://truvern.com" }

Ok "Production build complete"
Write-Host "✅ Prod URL: $prod" -ForegroundColor Yellow
Write-Host "✅ Board UI: https://truvern.com/reports/board?org=demo-2128873b" -ForegroundColor Cyan
Write-Host "✅ CSV API: https://truvern.com/api/reports/board?org=demo-2128873b&format=csv" -ForegroundColor Cyan
Ok "Phase 74-Hotfix finished."
