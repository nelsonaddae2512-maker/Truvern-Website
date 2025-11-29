# ======================================================================
# Phase98-FixTrustNetworkAPI.ps1
# Creates /api/trust-network endpoint (App Router or Pages Router),
# builds, deploys to Vercel prod, re-aliases truvern.com + www,
# and verifies all key URLs.
# ======================================================================

[CmdletBinding()]
param(
  [string]$Root   = (Get-Location).Path,
  [string]$Domain = "truvern.com"
)
$ErrorActionPreference = "Stop"

function Write-Utf8($Path, $Content) {
  $dir = Split-Path $Path -Parent
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($false))
  Write-Host "Wrote: $Path"
}

Set-Location $Root
Write-Host "Working dir: $(Get-Location)" -ForegroundColor Yellow

# Detect App Router vs Pages Router
$hasApp   = Test-Path (Join-Path $Root "app")
$hasPages = Test-Path (Join-Path $Root "pages")

if ($hasApp) {
  # App Router path
  $apiPath = Join-Path $Root "app\api\trust-network\route.ts"
  $code = @'
import { NextResponse } from "next/server";

export async function GET() {
  try {
    // TODO: replace mock with real data source if needed
    const vendors = [
      { id: 1, name: "Default Vendor" },
      { id: 2, name: "Sample Partner" }
    ];
    return NextResponse.json({
      vendors,
      generatedAt: new Date().toISOString(),
    });
  } catch (error) {
    return NextResponse.json({ error: "Failed to load trust-network data" }, { status: 500 });
  }
}
'@
  Write-Utf8 $apiPath $code

} elseif ($hasPages) {
  # Pages Router path
  $apiPath = Join-Path $Root "pages\api\trust-network.ts"
  $code = @'
import type { NextApiRequest, NextApiResponse } from "next";

export default function handler(req: NextApiRequest, res: NextApiResponse) {
  try {
    const vendors = [
      { id: 1, name: "Default Vendor" },
      { id: 2, name: "Sample Partner" }
    ];
    res.status(200).json({ vendors, generatedAt: new Date().toISOString() });
  } catch (e) {
    res.status(500).json({ error: "Failed to load trust-network data" });
  }
}
'@
  Write-Utf8 $apiPath $code

} else {
  throw "Neither /app nor /pages found. Run from project root."
}

# Build & deploy
pnpm install
pnpm build

$deployOut = vercel --prod --yes
$deployed  = ($deployOut | Select-String -Pattern '\S+\.vercel\.app' -AllMatches).Matches.Value | Select-Object -Last 1
if (-not $deployed) {
  $deployed = (vercel ls --prod | Select-String -Pattern '\S+\.vercel\.app' -AllMatches).Matches.Value | Select-Object -First 1
}
if (-not $deployed) { throw "Could not determine deployed URL." }

vercel alias set $deployed $Domain        | Out-Null
vercel alias set $deployed ("www."+$Domain) | Out-Null
Write-Host ("Aliased {0} to {1}" -f $Domain,$deployed) -ForegroundColor Green

# Verify endpoints
$base = "https://$Domain"
[string[]]$urls = @(
  "$base/",
  "$base/trust-network",
  "$base/api/vendors",
  "$base/api/board",
  "$base/api/trust-network"
)
foreach ($u in $urls) {
  try {
    $r = Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 20
    Write-Host ("OK {0} -> HTTP {1}" -f $u, $r.StatusCode) -ForegroundColor Green
  } catch {
    $c = $_.Exception.Response.StatusCode.value__ 2>$null
    if ($c) { Write-Host ("WARN {0} -> HTTP {1}" -f $u,$c) -ForegroundColor DarkYellow }
    else    { Write-Host ("FAIL {0} -> {1}" -f $u,$_.Exception.Message) -ForegroundColor Red }
  }
}
