# Phase123f-PublicVerify.ps1
# Verify only public routes for the Truvern production deployment

$ErrorActionPreference = 'Stop'
$proj = (Get-Location).Path
$ts = Get-Date -Format "yyyyMMdd-HHmmss"
$logDir = Join-Path $proj "logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$vrfLog = Join-Path $logDir "route-public-verify-$ts.txt"

function Log([string]$msg, [string]$color='Cyan') {
  $line = "[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $msg
  $line | Tee-Object -FilePath $vrfLog -Append | Out-Host
}

# ---------- Base URL ----------
$base = "https://truvern.com"   # you can replace this with your active Vercel URL if needed
Log "Verifying public routes for $base"

# ---------- Public routes to check ----------
$routes = @(
  '/', '/pricing', '/login', '/subscribe', '/api/health', '/api/vendors', '/favicon.ico', '/manifest.json'
)

$okAll = $true
foreach ($r in $routes) {
  try {
    $u = "$base".TrimEnd('/') + $r
    $t0 = Get-Date
    $res = Invoke-WebRequest -UseBasicParsing -Uri $u -TimeoutSec 15
    $ms = [int]((Get-Date) - $t0).TotalMilliseconds
    if ($res.StatusCode -eq 200 -or $res.StatusCode -eq 304) {
      Log "✅ $u -> $($res.StatusCode) ($ms ms)" 'Green'
    } else {
      $okAll = $false
      Log "⚠️  $u -> $($res.StatusCode)" 'Yellow'
    }
  } catch {
    $okAll = $false
    Log "❌ $u -> $($_.Exception.Message)" 'Red'
  }
}

if ($okAll) {
  Log "`n✅ All public routes verified successfully." 'Green'
} else {
  Log "`n⚠️ Some public routes failed. See $vrfLog for details." 'Yellow'
}

Write-Host "`nVerification log: $vrfLog"
Write-Host "`nPress Enter to close..." -NoNewline
[void][Console]::ReadLine()
