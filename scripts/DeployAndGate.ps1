param(
  [string]$ProdUrl = "https://truvern.com",
  [string[]]$Paths = @("/ops/health","/api/health")
)
$ErrorActionPreference = "Stop"
Write-Host "== Truvern: Deploy + Health Gate ==" -ForegroundColor Cyan

vercel pull --yes --environment=production --token $env:VERCEL_TOKEN
vercel build --prod --token $env:VERCEL_TOKEN
$deployUrl = vercel deploy --prebuilt --prod --token $env:VERCEL_TOKEN
Write-Host "Deployed -> $deployUrl" -ForegroundColor Green

function Test-Url([string]$url) {
  for ($i=1; $i -le 5; $i++) {
    try {
      $r = Invoke-WebRequest -UseBasicParsing -TimeoutSec 15 -Uri $url
      if ($r.StatusCode -ge 200 -and $r.StatusCode -lt 400) { return $true }
    } catch { Start-Sleep -Seconds 2 }
    Start-Sleep -Seconds 3
  }
  return $false
}

foreach ($p in $Paths) {
  $u1 = "$ProdUrl$p"
  $u2 = "$deployUrl$p"
  Write-Host "Checking $u1" -ForegroundColor Cyan
  if (-not (Test-Url $u1)) { throw "FAILED: $u1" }
  Write-Host "Checking $u2" -ForegroundColor Cyan
  if (-not (Test-Url $u2)) { throw "FAILED: $u2" }
}

Write-Host "✅ Deploy health checks passed." -ForegroundColor Green