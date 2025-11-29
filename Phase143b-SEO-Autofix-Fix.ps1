<# =======================================================================
 Phase143b-SEO-Autofix-Fix.ps1
 Purpose: Fix AbsUrl and return handling for PowerShell 5, ensure layout
 cleanup, canonical & OG checks.
 ======================================================================= #>

$ErrorActionPreference='Stop'
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12

if ((Get-Location).Path -match '\\Windows\\System32$') {
  Write-Host "❌ Do not run from system32. cd into your project folder first." -ForegroundColor Red
  exit 1
}

$root=$pwd.Path
$ts=Get-Date -Format "yyyyMMdd-HHmmss"
$logs=Join-Path $root "logs"
$reports=Join-Path $root "reports"
New-Item -ItemType Directory -Force -Path $logs,$reports | Out-Null
$logFile=Join-Path $logs ("Phase143b-SEO-Autofix-Fix-" + $ts + ".log")
$jsonFile=Join-Path $reports ("Phase143b-SEO-Autofix-Fix-" + $ts + ".json")

function Log { param([string]$m,[string]$lvl="INFO")
  $line = "[{0}] [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"),$lvl,$m
  $line | Tee-Object -FilePath $logFile -Append | Out-Null
}

Write-Host "=== Phase143b: Repair AbsUrl and Verify SEO ===" -ForegroundColor Cyan

# --- Verification helpers ---
$Base="https://truvern.com"
function Fetch-Page {
  param([string]$url)
  $sw=[Diagnostics.Stopwatch]::StartNew()
  try {
    $r=Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 25
    $sw.Stop()
    return [pscustomobject]@{
      Url=$url; Status=[int]$r.StatusCode; OK=$true;
      TookMs=[int]$sw.ElapsedMilliseconds; Html=$r.Content
    }
  } catch {
    $sw.Stop()
    return [pscustomobject]@{
      Url=$url; Status=0; OK=$false;
      TookMs=[int]$sw.ElapsedMilliseconds; Html=""; Error=$_.Exception.Message
    }
  }
}

function MatchVal { 
  param($html,$regex)
  try {
    $m=[regex]::Match($html,$regex,[Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if ($m.Success) { return $m.Groups[1].Value.Trim() } else { return "" }
  } catch { return "" }
}

function AbsUrl {
  param($u,$b)
  if (-not $u) { return "" }
  if ($u -like "http*") { return $u }
  elseif ($u.StartsWith("//")) { return "https:" + $u }
  elseif ($u.StartsWith("/")) { return $b + $u }
  else { return ($b.TrimEnd('/') + "/" + $u.TrimStart('/')) }
}

function Head200 {
  param($url)
  if (-not $url) { return 0 }
  try { 
    $r=Invoke-WebRequest -Uri $url -Method Head -UseBasicParsing -TimeoutSec 10
    return $r.StatusCode
  } catch { return 0 }
}

# --- Verify ---
$paths=@("/","/trust-network","/reports/board","/vendors")
$verify=@()
foreach($p in $paths){
  $url="$Base$p"
  $pg=Fetch-Page $url
  $ogi=MatchVal $pg.Html "<meta[^>]+property=['""]og:image['""][^>]+content=['""](.*?)['""]"
  $ogiAbs=AbsUrl $ogi $Base
  $ogStatus=Head200 $ogiAbs
  $can=MatchVal $pg.Html "<link[^>]+rel=['""]canonical['""][^>]+href=['""](.*?)['""]"
  $canAbs=AbsUrl $can $Base
  $canOK=$false
  if ($canAbs) {
    try {
      $canHost=([uri]$canAbs).Host
      $baseHost=([uri]$Base).Host
      $canOK=($canHost -eq $baseHost)
    } catch { $canOK=$false }
  }
  $verify += [pscustomobject]@{
    Path=$p; HTTP=$pg.Status; OK=$pg.OK;
    OGImage=$ogiAbs; OGHTTP=$ogStatus;
    Canonical=$canAbs; HostOK=$canOK
  }
}

# --- Save ---
$summary=[pscustomobject]@{
  Phase="Phase143b-SEO-Autofix-Fix"
  Timestamp=(Get-Date).ToString("s")
  Base=$Base
  Verify=$verify
}
$summary|ConvertTo-Json -Depth 6|Out-File -FilePath $jsonFile -Encoding UTF8
Log "JSON report -> $jsonFile"

Write-Host "`nVerification results:" -ForegroundColor Cyan
"{0,-16} {1,5} {2,5} {3,-36} {4,6} {5,-36} {6,6}" -f "Path","HTTP","OK","OG Image","OG","Canonical","HostOK"
foreach ($v in $verify) {
  $ogImg = if ($v.OGImage) { $v.OGImage } else { "" }
  $canVal = if ($v.Canonical) { $v.Canonical } else { "" }
  "{0,-16} {1,5} {2,5} {3,-36} {4,6} {5,-36} {6,6}" -f $v.Path, $v.HTTP, $v.OK, $ogImg, $v.OGHTTP, $canVal, $v.HostOK | Write-Host
}

Write-Host "`nJSON report: $jsonFile"
Write-Host "Log saved:   $logFile"
Write-Host "`nPhase143b complete." -ForegroundColor Green
