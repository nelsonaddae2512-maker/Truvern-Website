# Phase62-Verify.ps1 — confirms files & probes endpoint
$ErrorActionPreference = "Stop"
$root = (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $root

$apiFile = Join-Path $root "app\api\reports\board\route.ts"
if (Test-Path $apiFile) {
  Write-Host "Found: $apiFile" -ForegroundColor Green
} else {
  Write-Host "Missing API file: $apiFile" -ForegroundColor Red
  exit 1
}

$last = Join-Path $root "last-org-id.txt"
$org = if (Test-Path $last) { (Get-Content $last -ErrorAction SilentlyContinue).Trim() } else { $null }
if ([string]::IsNullOrWhiteSpace($org)) { $org = "demo-2128873b" }

$u = "https://truvern.com/api/reports/board?org=$org"
Write-Host "Probing: $u" -ForegroundColor Cyan
try {
  $r = Invoke-WebRequest -Uri $u -TimeoutSec 20 -UseBasicParsing
  Write-Host ("Status: {0}" -f $r.StatusCode) -ForegroundColor Green
  if ($r.Content) {
    $snippet = $r.Content.Substring(0, [Math]::Min(300, $r.Content.Length))
    Write-Host $snippet -ForegroundColor DarkGray
  }
} catch {
  Write-Host ("Probe failed: " + $_.Exception.Message) -ForegroundColor Yellow
  exit 2
}
