# Phase74-NodeDirect.ps1 — direct Node-based deploy (bypasses PowerShell shim)
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
Ok "Found Vercel CLI JS: $vcPath"

Sec "Running direct deploy via node.exe"
$nodeExe = (Get-Command node).Source
Ok "Using Node: $nodeExe"

# Pull environment
& $nodeExe $vcPath pull --environment=production --yes
if ($LASTEXITCODE -ne 0) { throw "vercel pull failed" }

# Deploy production
$out = & $nodeExe $vcPath deploy --prod --yes 2>&1
$out | Out-Host
if ($LASTEXITCODE -ne 0) { throw "vercel deploy failed" }

# Extract production URL
$prod = ($out | Select-String -Pattern "https://[^ ]+\.vercel\.app").Matches.Value | Select-Object -Last 1
if (-not $prod) { $prod = "https://truvern.com" }

Ok "✅ Production build complete!"
Write-Host "Prod URL: $prod" -ForegroundColor Yellow
Write-Host "UI : https://truvern.com/reports/board?org=demo-2128873b" -ForegroundColor Cyan
Write-Host "CSV: https://truvern.com/api/reports/board?org=demo-2128873b&format=csv" -ForegroundColor Cyan
Ok "Phase74-NodeDirect complete."
