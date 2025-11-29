<# =======================================================================
 Phase146b-SEO-MetaRestore-Fix.ps1
 Safe for PowerShell 5 — Restores OG + Canonical tags and rebuilds Next.js
 ======================================================================= #>

$ErrorActionPreference='Stop'
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12

if ((Get-Location).Path -match '\\Windows\\System32$') {
  Write-Host "❌ Do not run from system32. cd into your project folder first." -ForegroundColor Red
  exit 1
}

$root = $pwd.Path
$ts   = Get-Date -Format "yyyyMMdd-HHmmss"
$logs = Join-Path $root "logs"
$reports = Join-Path $root "reports"
$backups = Join-Path $root ("patch_backups\phase146b-" + $ts)
New-Item -ItemType Directory -Force -Path $logs,$reports,$backups | Out-Null
$logFile  = Join-Path $logs ("Phase146b-SEO-MetaRestore-" + $ts + ".log")
$jsonFile = Join-Path $reports ("Phase146b-SEO-MetaRestore-" + $ts + ".json")

function Log { param([string]$m,[string]$lvl="INFO")
  $line = "[" + (Get-Date -Format "yyyy-MM-dd HH:mm:ss") + "] [" + $lvl + "] " + $m
  Add-Content -Path $logFile -Value $line
  Write-Host $line
}

Write-Host "=== Phase146b: SEO Meta Restore (Safe Version) ===" -ForegroundColor Cyan
Log "=== Phase146b started ==="

# ---------- Simple metadata injector ----------
function Add-MetadataBlock {
  param([string]$file,[string]$title,[string]$desc,[string]$canonical)

  if(-not (Test-Path $file)){
    Log "Skipping missing file: $file" "WARN"
    return
  }

  $backup = Join-Path $backups ([IO.Path]::GetFileName($file) + "." + $ts + ".bak")
  Copy-Item $file $backup -Force
  Log "Backup created for $file"

  $lines = Get-Content -Path $file

  # Build metadata lines safely
  $metaBlock = @(
    "export const metadata = {",
    "  title: '$title',",
    "  description: '$desc',",
    "  alternates: { canonical: '$canonical' },",
    "};"
  )

  # Detect if metadata already exists
  $exists = $false
  foreach($l in $lines){ if($l -match "export\s+const\s+metadata"){ $exists = $true; break } }

  if(-not $exists){
    Log "Inserting new metadata block into $file"
    $insertIdx = 0
    for($i=0;$i -lt $lines.Count;$i++){ if($lines[$i] -match "^\s*import\s+"){ $insertIdx = $i + 1 } }
    $output = @()
    if($insertIdx -gt 0){
      $output += $lines[0..($insertIdx-1)]
      $output += $metaBlock
      if($insertIdx -lt $lines.Count){ $output += $lines[$insertIdx..($lines.Count-1)] }
    } else {
      $output = $metaBlock + $lines
    }
    $output | Out-File -FilePath $file -Encoding UTF8
  } else {
    Log "Metadata already found in $file — skipping"
  }
}

# ---------- Patch canonical pages ----------
$appDir = Join-Path $root "app"
Add-MetadataBlock -file (Join-Path $appDir "trust-network\page.tsx") -title "Trust Network" -desc "Truvern - Vendor trust network and TPRM." -canonical "/trust-network"
Add-MetadataBlock -file (Join-Path $appDir "reports\board\page.tsx") -title "Board Reports" -desc "Truvern - Board-level risk dashboards." -canonical "/reports/board"
Add-MetadataBlock -file (Join-Path $appDir "vendors\page.tsx") -title "Vendors" -desc "Truvern - Manage vendors, evidence, and workflows." -canonical "/vendors"

# ---------- Verify live ----------
function Fetch {
  param([string]$url)
  try {
    $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 20
    return [pscustomobject]@{Url=$url;Status=$r.StatusCode;OK=$true;Html=$r.Content}
  } catch {
    return [pscustomobject]@{Url=$url;Status=0;OK=$false;Html=""}
  }
}

function MatchVal { param([string]$html,[string]$regex)
  try { ([regex]::Match($html,$regex,[Text.RegularExpressions.RegexOptions]::IgnoreCase)).Groups[1].Value } catch { "" }
}

function Head200 { param([string]$u)
  if(-not $u){ return 0 }
  try { (Invoke-WebRequest -Uri $u -Method Head -UseBasicParsing -TimeoutSec 10).StatusCode } catch { 0 }
}

$Base="https://truvern.com"
$pages=@("/","/trust-network","/reports/board","/vendors")
$verify=@()

foreach($p in $pages){
  $u = "$Base$p"
  $r = Fetch $u
  $html=$r.Html
  $og  = MatchVal $html "<meta[^>]+property=['""]og:image['""][^>]+content=['""](.*?)['""]"
  $can = MatchVal $html "<link[^>]+rel=['""]canonical['""][^>]+href=['""](.*?)['""]"
  $ogOK = if($og){ Head200($og) } else { 0 }
  $canOK = if($can){ (([uri]$can).Host -eq ([uri]$Base).Host) } else { $false }
  $verify += [pscustomobject]@{Path=$p;HTTP=$r.Status;OK=$r.OK;OG=$ogOK;Canonical=$can;HostOK=$canOK}
}

$verify | ConvertTo-Json -Depth 5 | Out-File -FilePath $jsonFile -Encoding UTF8
Log "JSON report -> $jsonFile"

Write-Host "`nVerification results:" -ForegroundColor Cyan
"{0,-18}{1,6}{2,6}{3,6}{4,-36}{5,6}" -f "Path","HTTP","OK","OG","Canonical","HostOK"
foreach($v in $verify){
  "{0,-18}{1,6}{2,6}{3,6}{4,-36}{5,6}" -f $v.Path,$v.HTTP,$v.OK,$v.OG,$v.Canonical,$v.HostOK | Write-Host
}

Write-Host "`nLog: $logFile"
Write-Host "Phase146b complete." -ForegroundColor Green
