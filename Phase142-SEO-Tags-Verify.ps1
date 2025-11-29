<# =======================================================================
 Phase142-SEO-Tags-Verify-Safe.ps1
 Purpose: Cross-check title, description, OG, canonical, sitemap, robots
 Compatible: Windows PowerShell 5.x
 ======================================================================= #>

#region Setup
$ErrorActionPreference='Stop'
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12

if ((Get-Location).Path -match '\\Windows\\System32$') {
  Write-Host "❌ Run from your project folder, not system32." -ForegroundColor Red
  exit 1
}

$ts = Get-Date -Format "yyyyMMdd-HHmmss"
$logsDir="$pwd\\logs";$reportsDir="$pwd\\reports"
New-Item -ItemType Directory -Force -Path $logsDir,$reportsDir|Out-Null
$logFile="$logsDir\\Phase142-SEO-Tags-Verify-$ts.log"
$jsonFile="$reportsDir\\Phase142-SEO-Tags-Verify-$ts.json"

function Write-Log {param([string]$m,[string]$lvl="INFO")]
  $line="[${(Get-Date -Format "yyyy-MM-dd HH:mm:ss")}] [$lvl] $m"
  $line|Tee-Object -FilePath $logFile -Append|Out-Null
}
Write-Log "=== Phase142: SEO-Tags-Verify-Safe ==="
#endregion

#region Config
$Base="https://truvern.com"
$pages=@("/","/trust-network","/reports/board","/vendors")
$extras=@("/sitemap.xml","/robots.txt")
#endregion

#region Helpers
function Fetch-Page {
  param([string]$url)
  $sw=[Diagnostics.Stopwatch]::StartNew()
  try{
    $r=Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 25
    $sw.Stop()
    [pscustomobject]@{Url=$url;Status=[int]$r.StatusCode;OK=$true;TookMs=[int]$sw.ElapsedMilliseconds;Html=$r.Content}
  }catch{
    $sw.Stop()
    [pscustomobject]@{Url=$url;Status=0;OK=$false;TookMs=[int]$sw.ElapsedMilliseconds;Error=$_.Exception.Message;Html=""}
  }
}
function Match-Val{param([string]$html,[string]$re)
  try{($html|Select-String -Pattern $re -AllMatches).Matches[0].Groups[1].Value.Trim()}catch{""}}
function Abs-Url{param([string]$u,[string]$base)
  if(-not $u){return ""};if($u -like "http*"){return $u}
  if($u.StartsWith("//")){"https:"+$u}
  elseif($u.StartsWith("/")){$base+$u}
  else{$base.TrimEnd("/")+"/"+$u.TrimStart("/")}
}
function Head-200{param([string]$u)
  if(-not $u){return 0}
  try{(Invoke-WebRequest -Uri $u -Method Head -UseBasicParsing -TimeoutSec 15).StatusCode}catch{0}
}
#endregion

#region Audit
$results=@()
foreach($p in $pages){
  $url="$Base$p";Write-Log "Checking $url"
  $pg=Fetch-Page $url
  $t=Match-Val $pg.Html "<title>(.*?)</title>"
  if(-not $t){$t=Match-Val $pg.Html "<meta[^>]+property=['""]og:title['""][^>]+content=['""](.*?)['""]"}
  $d=Match-Val $pg.Html "<meta[^>]+name=['""]description['""][^>]+content=['""](.*?)['""]"
  $ogt=Match-Val $pg.Html "<meta[^>]+property=['""]og:title['""][^>]+content=['""](.*?)['""]"
  $ogd=Match-Val $pg.Html "<meta[^>]+property=['""]og:description['""][^>]+content=['""](.*?)['""]"
  $ogi=Match-Val $pg.Html "<meta[^>]+property=['""]og:image['""][^>]+content=['""](.*?)['""]"
  $can=Match-Val $pg.Html "<link[^>]+rel=['""]canonical['""][^>]+href=['""](.*?)['""]"
  $tLen=if($t){$t.Length}else{0};$dLen=if($d){$d.Length}else{0}
  $tOK=($tLen -ge 10 -and $tLen -le 70)
  $dOK=($dLen -ge 50 -and $dLen -le 160)
  $ogiAbs=Abs-Url $ogi $Base;$ogiStat=Head-200 $ogiAbs
  $canOK=$false
  if($can){
    $canAbs=Abs-Url $can $Base
    try{$canHost=([uri]$canAbs).Host;$baseHost=([uri]$Base).Host;$canOK=($canHost -eq $baseHost)}catch{$canOK=$false}
  }
  $results+= [pscustomobject]@{
    Path=$p;Status=$pg.Status;OK=$pg.OK;TookMs=$pg.TookMs;
    Title=$t;TitleLen=$tLen;TitleOK=$tOK;
    Desc=$d;DescLen=$dLen;DescOK=$dOK;
    OGImage=$ogiAbs;OGStatus=$ogiStat;
    Canonical=$can;CanonOK=$canOK
  }
}

$extra=@()
foreach($x in $extras){
  $u="$Base$x";$r=Fetch-Page $u
  $extra+=[pscustomobject]@{Path=$x;Status=$r.Status;OK=$r.OK;TookMs=$r.TookMs}
}
#endregion

#region Output
$report=[pscustomobject]@{Phase="Phase142-SEO-Tags-Verify-Safe";Base=$Base;Timestamp=(Get-Date).ToString("s");Pages=$results;Extras=$extra}
$report|ConvertTo-Json -Depth 5|Out-File $jsonFile -Encoding UTF8
Write-Log "Saved -> $jsonFile"

Write-Host "`nSummary:" -ForegroundColor Cyan
"{0,-16} {1,5} {2,5} {3,6} {4,7} {5,6} {6,7}" -f "Path","HTTP","OK","TLen","T ok?","DLen","D ok?"
foreach($r in $results){
  "{0,-16} {1,5} {2,5} {3,6} {4,7} {5,6} {6,7}" -f $r.Path,$r.Status,$r.OK,$r.TitleLen,$r.TitleOK,$r.DescLen,$r.DescOK|Write-Host
}
Write-Host "`nOG image checks:" -ForegroundColor Cyan
"{0,-16} {1,-40} {2,6}" -f "Path","OG Image","HTTP"
foreach($r in $results){
  $og=$r.OGImage;if(-not $og){$og=""}
  "{0,-16} {1,-40} {2,6}" -f $r.Path,$og,$r.OGStatus|Write-Host
}
Write-Host "`nCanonical host consistency:" -ForegroundColor Cyan
"{0,-16} {1,-40} {2,8}" -f "Path","Canonical","HostOK"
foreach($r in $results){
  $can=$r.Canonical;if(-not $can){$can=""}
  "{0,-16} {1,-40} {2,8}" -f $r.Path,$can,$r.CanonOK|Write-Host
}
Write-Host "`nExtras:" -ForegroundColor Cyan
"{0,-16} {1,5} {2,5}" -f "Path","HTTP","OK"
foreach($r in $extra){
  "{0,-16} {1,5} {2,5}" -f $r.Path,$r.Status,$r.OK|Write-Host
}

Write-Host "`nJSON report: $jsonFile"
Write-Host "Log saved:   $logFile`n"
Write-Host "Phase142 complete." -ForegroundColor Green
#endregion
