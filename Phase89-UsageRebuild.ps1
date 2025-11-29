param(
  [string]$Plan = "free",
  [int]$Vendors = 2,
  [int]$Members = 1,
  [int]$Assessments = 0,
  [switch]$NoDeploy
)
$ErrorActionPreference = "Stop"

try {
  if ($MyInvocation.MyCommand.Path) {
    $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
    Set-Location $scriptRoot
  }
} catch {}

function Ensure-Vercel {
  try { (Get-Command vercel -ErrorAction Stop) | Out-Null }
  catch {
    Write-Host "Installing Vercel CLI..." -ForegroundColor Yellow
    npm i -g vercel | Out-Host
    (Get-Command vercel -ErrorAction Stop) | Out-Null
  }
}

function Set-VercelEnv([string]$Name, [string]$Value, [string]$Target="production") {
  # remove old key (ignore errors)
  cmd /c "vercel env rm $Name $Target -y 1>nul 2>nul" | Out-Null
  # add new value
  $add = "echo $Value | vercel env add $Name $Target"
  $out = cmd /c $add
  if ($LASTEXITCODE -ne 0) { throw "Failed to set Vercel env '$Name'. Output: $out" }
  Write-Host "✔ Vercel env set: $Name=$Value"
}

# ---- write /api/usage route ----
$usagePath = Join-Path (Get-Location).Path "app\api\usage\route.ts"
$usageDir  = Split-Path $usagePath -Parent
if (-not (Test-Path $usageDir)) { New-Item -ItemType Directory -Path $usageDir | Out-Null }

$usageTs = @"
import { NextResponse } from "next/server";

export async function GET() {
  const plan = process.env.APP_PLAN || "free";
  const vendors = Number(process.env.USAGE_VENDORS || 0);
  const members = Number(process.env.USAGE_MEMBERS || 0);
  const assessments = Number(process.env.USAGE_ASSESSMENTS || 0);

  return NextResponse.json({
    ok: true,
    usage: [
      { key: "plan", value: plan },
      { key: "vendors", value: vendors },
      { key: "members", value: members },
      { key: "assessments", value: assessments }
    ]
  });
}
"@
Set-Content -LiteralPath $usagePath -Value $usageTs -Encoding UTF8
Write-Host "Updated $usagePath"

# ---- push envs and deploy ----
Ensure-Vercel
Write-Host "Syncing envs to Vercel (production)..." -ForegroundColor Yellow
Set-VercelEnv "APP_PLAN"          "$Plan"
Set-VercelEnv "USAGE_VENDORS"     "$Vendors"
Set-VercelEnv "USAGE_MEMBERS"     "$Members"
Set-VercelEnv "USAGE_ASSESSMENTS" "$Assessments"
Set-VercelEnv "APP_URL"           "https://truvern.com"

Write-Host "`nPulling Vercel config..." -ForegroundColor Cyan
vercel pull --environment=production --yes

if (-not $NoDeploy) {
  Write-Host "`nDeploying to production..." -ForegroundColor Cyan
  vercel deploy --prod --yes
} else {
  Write-Host "(NoDeploy) Skipping deploy step."
}

# ---- verify endpoints ----
try { Add-Type -AssemblyName System.Net.Http } catch {}
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$client = New-Object System.Net.Http.HttpClient
$client.Timeout = [TimeSpan]::FromSeconds(20)

function Get-Json([string]$url) {
  try {
    $r = $client.GetAsync($url).Result
    $code = [int]$r.StatusCode
    $txt  = $r.Content.ReadAsStringAsync().Result
    Write-Host ("GET {0} -> {1}" -f $url, $code)
    return $txt
  } catch { Write-Host ("GET {0} -> ERR {1}" -f $url, $_.Exception.Message) -ForegroundColor Red; return "" }
}

function Post-Json([string]$url, [string]$json) {
  try {
    $content = New-Object System.Net.Http.StringContent($json, [Text.Encoding]::UTF8, "application/json")
    $r = $client.PostAsync($url, $content).Result
    $code = [int]$r.StatusCode
    $txt  = $r.Content.ReadAsStringAsync().Result
    Write-Host ("POST {0} -> {1}" -f $url, $code)
    return $txt
  } catch { Write-Host ("POST {0} -> ERR {1}" -f $url, $_.Exception.Message) -ForegroundColor Red; return "" }
}

$base = "https://truvern.com"

Write-Host "`n== Verify /api/usage ==" -ForegroundColor Cyan
$usageOut = Get-Json "$base/api/usage"; if ($usageOut) { Write-Host $usageOut }

Write-Host "`n== Verify Stripe endpoints ==" -ForegroundColor Cyan
$checkout = Post-Json "$base/api/stripe/checkout" '{"plan":"pro"}'; if ($checkout) { Write-Host $checkout }
$portal   = Get-Json  "$base/api/stripe/portal?cid=fake";         if ($portal)   { Write-Host $portal }

$client.Dispose()
Write-Host "`nPhase 89 complete: usage + envs pushed, deployed, and verified." -ForegroundColor Green
