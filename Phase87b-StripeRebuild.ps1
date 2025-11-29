# ===================================================================
# Phase87b-StripeRebuild.ps1 (fixed version)
# Force full rebuild to fix 501 errors for Stripe routes
# ===================================================================
$ErrorActionPreference = 'Stop'
$root = "C:\Users\MR.NELSON\Downloads\truvern"
Set-Location $root
Write-Host "== Phase 87b: Stripe Rebuild & Verify ==" -ForegroundColor Cyan

try { Add-Type -AssemblyName System.Net.Http } catch {}
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# --- 1. Confirm route files ---
$files = @(
  "$root\app\api\stripe\checkout\route.ts",
  "$root\app\api\stripe\portal\route.ts"
)
foreach ($f in $files) {
  if (Test-Path $f) {
    $s = (Get-Item $f).Length
    Write-Host "✓ Found $f ($s bytes)"
  } else {
    Write-Warning "Missing $f"
  }
}

# --- 2. Clear prebuilt cache ---
if (Test-Path "$root\.vercel\output") {
  Remove-Item "$root\.vercel\output" -Recurse -Force -ErrorAction SilentlyContinue
  Write-Host "Cleared .vercel/output cache." -ForegroundColor Yellow
} else {
  Write-Host "No .vercel/output present (ok)"
}

# --- 3. Rebuild + deploy ---
Write-Host "`nPulling envs and forcing new production build..." -ForegroundColor Cyan
vercel pull --environment=production --yes
vercel deploy --prod --yes

# --- 4. Verify endpoints ---
$urls = @(
  "https://truvern.com/api/stripe/checkout",
  "https://truvern.com/api/stripe/portal?cid=fake"
)

$client = New-Object System.Net.Http.HttpClient
$client.Timeout = [TimeSpan]::FromSeconds(15)

foreach ($u in $urls) {
  try {
    $req = New-Object System.Net.Http.HttpRequestMessage ([System.Net.Http.HttpMethod]::Get), $u
    $res = $client.SendAsync($req).Result
    $code = [int]$res.StatusCode
    Write-Host ("{0} -> {1}" -f $code, $u)
  } catch {
    Write-Host ("ERR -> {0}" -f $_.Exception.Message) -ForegroundColor Red
  }
}
$client.Dispose()

Write-Host "`nPhase 87b complete." -ForegroundColor Green
# ===================================================================
