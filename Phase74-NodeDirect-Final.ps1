# Phase74-NodeDirect-Final.ps1 — fully detached Node deploy runner
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Sec($t){ Write-Host "`n=== $t ===" -ForegroundColor Cyan }
function Ok($t){ Write-Host $t -ForegroundColor Green }

Sec "Locating true Vercel CLI JS file"
$globalNpm = (npm root -g).Trim()
$vcPath = Join-Path $globalNpm "vercel\dist\vc.js"

if (-not (Test-Path $vcPath)) {
    throw "Vercel CLI not found at $vcPath — reinstall via: npm i -g vercel"
}
Ok "Found: $vcPath"

$nodeExe = (Get-Command node).Source
Ok "Using Node: $nodeExe"

Sec "Pulling production environment"
Start-Process -FilePath $nodeExe -ArgumentList "`"$vcPath`" pull --environment=production --yes" -NoNewWindow -Wait
if ($LASTEXITCODE -ne 0) { throw "vercel pull failed" }

Sec "Deploying production build"
$deployLog = "deploy_output.txt"
if (Test-Path $deployLog) { Remove-Item $deployLog -Force }
Start-Process -FilePath $nodeExe -ArgumentList "`"$vcPath`" deploy --prod --yes" -NoNewWindow -Wait -RedirectStandardOutput $deployLog
if ($LASTEXITCODE -ne 0) { throw "vercel deploy failed" }

# Read deployment output
$out = Get-Content $deployLog -Raw
$prod = ($out | Select-String -Pattern "https://[^ ]+\.vercel\.app").Matches.Value | Select-Object -Last 1
if (-not $prod) { $prod = "https://truvern.com" }

Ok "✅ Production build complete!"
Write-Host ("Prod URL: {0}" -f $prod) -ForegroundColor Yellow
Write-Host ("UI : https://truvern.com/reports/board?org=demo-2128873b") -ForegroundColor Cyan
Write-Host ("CSV: https://truvern.com/api/reports/board?org=demo-2128873b" + "&format=csv") -ForegroundColor Cyan
Ok "Phase74-NodeDirect-Final complete."

