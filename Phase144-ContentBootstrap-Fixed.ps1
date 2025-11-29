<# =======================================================================
 Phase144-ContentBootstrap-Fixed.ps1
 Purpose: Final post-deploy SEO + OG/Canonical bootstrap verification
 Compatible: PowerShell 5.x (no reserved variable overrides)
 ======================================================================= #>

$ErrorActionPreference='Stop'
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12

if ((Get-Location).Path -match '\\Windows\\System32$') {
  Write-Host "❌ Do not run from system32. cd into your project folder first." -ForegroundColor Red
  exit 1
}

$Root = $pwd.Path
$Ts = Get-Date -Format "yyyyMMdd-HHmmss"
$Logs = Join-Path $Root "logs"
$Reports = Join-Path $Root "reports"
New-Item -ItemType Directory -Force -Path $Logs,$Reports | Out-Null
$LogFile = Join-Path $Logs ("Phase144-ContentBootstrap-" + $Ts + ".log")
$JsonFile = Join-Path $Reports ("Phase144-ContentBootstrap-" + $Ts + ".json")

function Log { param([string]$m,[string]$lvl="INFO")
  $line = "[{0}] [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"),$lvl,$m
  $line | Tee-Object -FilePath $LogFile -Append | Out-Null
}

Write-Host "=== Phase144: PostDeploy Audit & SEO Bootstrap ===" -ForegroundColor Cyan
Log "=== Phase144 started ==="

# Use a neutral variable name (PowerShell 5-safe)
$HomeDir = Join-Path $Root "app"
if (-not (Test-Path $HomeDir)) {
  Write-Host "App directory not found. Check project structure." -ForegroundColor Red
  exit 1
}

# Core verification URLs
$Base = "https://truvern.com"
$Paths = @("/","/trust-network","/reports/board","/vendors","/sitemap.xml","/robots.txt")

function Fetch-Page {
  param([string]$Url)
  $sw=[Diagnostics.Stopwatch]::StartNew()
  try {
    $r=Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 25
    $sw.Stop()
    return [pscustomobject]@{
      Url=$Url; Status=[int]$r.StatusCode; OK=$true;
      TookMs=[int]$sw.ElapsedMilliseconds; Html=$r.Content
    }
  } catch {
    $sw.Stop()
    return [pscustomobject]@{
      Url=$Url; Status=0; OK=$false;
      TookMs=[int]$sw.ElapsedMilliseconds; Html=""; Error=$_.Exception.Message
    }
  }
}

function MatchVal { 
  param($Html,$Regex)
  try {
    $m=[regex]::Match($Html,$Regex,[Text.RegularExpressions.RegexOptions]::IgnoreCase)
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
  param($Url)
  if (-not $Url) { return 0 }
  try { 
    $r=Invoke-WebRequest -Uri $Url -Method Head -UseBasicParsing -TimeoutSec 10
    return $r.StatusCode
  } catch { return 0 }
}

# Perform checks
$Verify = @()
foreach ($p in $Paths) {
  $Url = "$Base$p"
  $Pg = Fetch-Page $Url
  $Ogi = MatchVal $Pg.Html "<meta[^>]+property=['""]og:image['""][^>]+content=['""](.*?)['""]"
  $OgiAbs = AbsUrl $Ogi $Base
  $OgStatus = Head200 $OgiAbs
  $Can = MatchVal $Pg.Html "<link[^>]+rel=['""]canonical['""][^>]+href=['""](.*?)['""]"
  $CanAbs = AbsUrl $Can $Base
  $CanOK = $false
  if ($CanAbs) {
    try {
      $CanHost=([uri]$CanAbs).Host
      $BaseHost=([uri]$Base).Host
      $CanOK=($CanHost -eq $BaseHost)
    } catch { $CanOK=$false }
  }
  $Verify += [pscustomobject]@{
    Path=$p; HTTP=$Pg.Status; OK=$Pg.OK;
    OGImage=$OgiAbs; OGHTTP=$OgStatus;
    Canonical=$CanAbs; HostOK=$CanOK
  }
}

# Generate structured output
$Summary=[pscustomobject]@{
  Phase="Phase144-ContentBootstrap"
  Timestamp=(Get-Date).ToString("s")
  Base=$Base
  Verify=$Verify
}
$Summary | ConvertTo-Json -Depth 6 | Out-File -FilePath $JsonFile -Encoding UTF8
Log "JSON report -> $JsonFile"

Write-Host "`nVerification Results:" -ForegroundColor Cyan
"{0,-16} {1,5} {2,5} {3,-36} {4,6} {5,-36} {6,6}" -f "Path","HTTP","OK","OG Image","OG","Canonical","HostOK"
foreach ($v in $Verify) {
  $ogImg = if ($v.OGImage) { $v.OGImage } else { "" }
  $canVal = if ($v.Canonical) { $v.Canonical } else { "" }
  "{0,-16} {1,5} {2,5} {3,-36} {4,6} {5,-36} {6,6}" -f $v.Path,$v.HTTP,$v.OK,$ogImg,$v.OGHTTP,$canVal,$v.HostOK | Write-Host
}

Write-Host "`nJSON report: $JsonFile"
Write-Host "Log saved:   $LogFile"
Write-Host "`nPhase144 complete." -ForegroundColor Green
