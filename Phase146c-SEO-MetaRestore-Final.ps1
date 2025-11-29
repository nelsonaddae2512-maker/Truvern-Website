<# =======================================================================
 Phase146c-SEO-MetaRestore-Final.ps1
 Purpose: Safely restore OG + Canonical tags in Truvern Next.js pages.
 Compatible: Windows PowerShell 5.x
 ======================================================================= #>

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

if ((Get-Location).Path -match '\\Windows\\System32$') {
  Write-Host "❌ Do not run from system32. cd into your project folder first." -ForegroundColor Red
  exit 1
}

$root = $pwd.Path
$ts = Get-Date -Format "yyyyMMdd-HHmmss"
$logs = Join-Path $root "logs"
$reports = Join-Path $root "reports"
$backups = Join-Path $root ("patch_backups\\phase146c-" + $ts)
New-Item -ItemType Directory -Force -Path $logs,$reports,$backups | Out-Null
$logFile = Join-Path $logs ("Phase146c-SEO-MetaRestore-" + $ts + ".log")
$jsonFile = Join-Path $reports ("Phase146c-SEO-MetaRestore-" + $ts + ".json")

function Log {
  param([string]$msg)
  $line = "[" + (Get-Date -Format "HH:mm:ss") + "] " + $msg
  Add-Content -Path $logFile -Value $line
  Write-Host $line
}

Write-Host "=== Phase146c: SEO Meta Restore (Final) ===" -ForegroundColor Cyan
Log "Started Phase146c at $ts"

# ---- Safe Metadata Inserter ----
function Add-MetadataBlock {
  param([string]$file,[string]$title,[string]$desc,[string]$canonical)
  if (-not (Test-Path $file)) {
    Log "Skipping missing file: $file"
    return
  }
  $backup = Join-Path $backups ([IO.Path]::GetFileName($file) + "." + $ts + ".bak")
  Copy-Item $file $backup -Force
  Log "Backup -> $backup"

  $lines = Get-Content -Path $file
  $hasMeta = $false
  foreach ($l in $lines) { if ($l -match "export\s+const\s+metadata") { $hasMeta = $true } }

  if (-not $hasMeta) {
    Log "Inserting metadata block in $file"
    $meta = @(
      "export const metadata = {",
      "  title: '$title',",
      "  description: '$desc',",
      "  alternates: { canonical: '$canonical' },",
      "};"
    )
    $insertIndex = 0
    for ($i=0; $i -lt $lines.Count; $i++) {
      if ($lines[$i] -match '^\s*import\s+') { $insertIndex = $i + 1 }
    }
    $out = @()
    if ($insertIndex -gt 0) {
      $out += $lines[0..($insertIndex-1)]
      $out += $meta
      if ($insertIndex -lt $lines.Count) { $out += $lines[$insertIndex..($lines.Count-1)] }
    } else {
      $out = $meta + $lines
    }
    $out | Out-File -FilePath $file -Encoding UTF8
  } else {
    Log "Metadata already exists in $file"
  }
}

# ---- Inject metadata blocks ----
$appDir = Join-Path $root "app"
Add-MetadataBlock -file (Join-Path $appDir "trust-network\\page.tsx") -title "Trust Network" -desc "Truvern - Vendor trust network and TPRM." -canonical "/trust-network"
Add-MetadataBlock -file (Join-Path $appDir "reports\\board\\page.tsx") -title "Board Reports" -desc "Truvern - Board-level risk dashboards." -canonical "/reports/board"
Add-MetadataBlock -file (Join-Path $appDir "vendors\\page.tsx") -title "Vendors" -desc "Truvern - Manage vendors and workflows." -canonical "/vendors"

# ---- Simple verification ----
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

function Head200 {
  param([string]$u)
  if (-not $u) { return 0 }
  try { (Invoke-WebRequest -Uri $u -Method Head -UseBasicParsing -TimeoutSec 10).StatusCode } catch { 0 }
}

$Base = "https://truvern.com"
$pages = @("/","/trust-network","/reports/board","/vendors")
$verify = @()

foreach ($p in $pages) {
  $u = "$Base$p"
  $r = Fetch $u
  $html = $r.Html
  $og = MatchVal $html "<meta[^>]+property=['""]og:image['""][^>]+content=['""](.*?)['""]"
  $can = MatchVal $html "<link[^>]+rel=['""]canonical['""][^>]+href=['""](.*?)['""]"
  $ogOK = if ($og) { Head200($og) } else { 0 }
  $canOK = if ($can) { (([uri]$can).Host -eq ([uri]$Base).Host) } else { $false }
  $verify += [pscustomobject]@{Path=$p;HTTP=$r.Status;OK=$r.OK;OG=$ogOK;Canonical=$can;HostOK=$canOK}
}

$verify | ConvertTo-Json -Depth 4 | Out-File -FilePath $jsonFile -Encoding UTF8
Log "JSON report -> $jsonFile"

Write-Host "`nVerification Results:" -ForegroundColor Cyan
"{0,-18}{1,6}{2,6}{3,6}{4,-36}{5,6}" -f "Path","HTTP","OK","OG","Canonical","HostOK"
foreach ($v in $verify) {
  "{0,-18}{1,6}{2,6}{3,6}{4,-36}{5,6}" -f $v.Path,$v.HTTP,$v.OK,$v.OG,$v.Canonical,$v.HostOK | Write-Host
}

Write-Host "`nLog: $logFile"
Write-Host "Phase146c complete." -ForegroundColor Green
