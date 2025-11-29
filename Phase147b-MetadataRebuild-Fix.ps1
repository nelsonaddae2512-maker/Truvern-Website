<# =======================================================================
 Phase147b-MetadataRebuild-Fix.ps1
 Purpose: Force Next.js metadata rebuild and verify OG + canonical tags
 ======================================================================= #>

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Host "=== Phase147b: Metadata Rebuild & Verification ===" -ForegroundColor Cyan

# Step 1: Ensure we’re not in system32
if ((Get-Location).Path -match '\\Windows\\System32$') {
  Write-Host "❌ Please cd into your project folder (e.g. C:\Users\MR.NELSON\Downloads\truvern)" -ForegroundColor Red
  exit 1
}

# Step 2: Clean old build caches
if (Test-Path ".next") { Remove-Item ".next" -Recurse -Force }
if (Test-Path ".vercel\output") { Remove-Item ".vercel\output" -Recurse -Force }

Write-Host "🧹 Cleared .next and .vercel caches." -ForegroundColor Yellow

# Step 3: Run a fresh build
Write-Host "🚀 Running pnpm build..." -ForegroundColor Cyan
pnpm run build

# Step 4: Optional prebuilt check (skip if not needed)
Write-Host "🧩 Running vercel build (local prebuilt test)..." -ForegroundColor Cyan
vercel build

# Step 5: Verify OG and Canonical presence
$Base = "https://truvern.com"
$pages = @("/","/trust-network","/reports/board","/vendors")
$results = @()

function Fetch {
  param([string]$url)
  try {
    $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 20
    return [pscustomobject]@{Url=$url;Status=$r.StatusCode;OK=$true;Html=$r.Content}
  } catch {
    return [pscustomobject]@{Url=$url;Status=0;OK=$false;Html=""}
  }
}

function MatchVal {
  param([string]$html,[string]$regex)
  try { ([regex]::Match($html,$regex,[Text.RegularExpressions.RegexOptions]::IgnoreCase)).Groups[1].Value } catch { "" }
}

foreach ($p in $pages) {
  $u = "$Base$p"
  $r = Fetch $u
  $html = $r.Html
  $og = MatchVal $html "<meta[^>]+property=['""]og:image['""][^>]+content=['""](.*?)['""]"
  $can = MatchVal $html "<link[^>]+rel=['""]canonical['""][^>]+href=['""](.*?)['""]"
  $ogOK = if ($og) { "Found" } else { "Missing" }
  $canOK = if ($can) { $can } else { "Missing" }
  $results += [pscustomobject]@{Path=$p;HTTP=$r.Status;OG=$ogOK;Canonical=$canOK}
}

Write-Host "`nVerification Results:" -ForegroundColor Cyan
"{0,-18}{1,6}{2,-12}{3,-60}" -f "Path","HTTP","OG","Canonical"
foreach ($v in $results) {
  "{0,-18}{1,6}{2,-12}{3,-60}" -f $v.Path,$v.HTTP,$v.OG,$v.Canonical | Write-Host
}

Write-Host "`nPhase147b complete. Rebuild and verification finished." -ForegroundColor Green
