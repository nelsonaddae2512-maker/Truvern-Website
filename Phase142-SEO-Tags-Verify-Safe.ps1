<# =======================================================================
 Phase142-SEO-Tags-Verify-Safe.ps1
 Purpose: SEO audit for Truvern (titles, descriptions, OG, canonical)
 Compatible: Windows PowerShell 5.x
 ======================================================================= #>

$ErrorActionPreference='Stop'
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12

if ((Get-Location).Path -match '\\Windows\\System32$') {
  Write-Host "❌ Run from your project folder, not system32." -ForegroundColor Red; exit 1
}

$ts = Get-Date -Format "yyyyMMdd-HHmmss"
$logsDir="$pwd\\logs";$reportsDir="$pwd\\reports"
New-Item -ItemType Directory -Force -Path $logsDir,$reportsDir|Out-Null
$logFile="$logsDir\\Phase142-SEO-Tags-Verify-$ts.log"
$jsonFile="$reportsDir\\Phase142-SEO-Tags-Verify-$ts.json"

function Write-Log {param([string]$m,[string]$lvl="INFO")]
  $l="[${(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')}] [$lvl] $m"
  $l|Tee-Object -FilePath $logFile -Append|Out-Null
}
Write-Log "=== Phase142: SEO-Tags-Verify-Safe ==="

$Base="https://truvern.com"
$pages=@("/","/trust-network","/reports/board","/vendors")
$extras=@("/sitemap.xml","/robots.txt")

function Fetch {param([string]$u)
  $sw=[Diagnostics.Stopwatch]::StartNew()
  try{$r=Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 25
      $sw.Stop();[pscustomobject]@{Url=$u;Status=[int]$r.StatusCode;OK=$true;TookMs=[int]$sw.ElapsedMilliseconds;Html=$r.Content}}
  catch{$sw.Stop();[pscustomobject]@{Url=$u;Status=0;OK=$false;TookMs=[int]$sw.ElapsedMilliseconds;Error=$_.Exception.Message;Html=""}}
}
function MatchVal{param($h,$r)
  try{([regex]::Match($h,$r,[Text.RegularExpressions.RegexOptions]::IgnoreCase)).Groups[1].Value.Trim()}catch{""}}
function AbsUrl{param($u,$b)
  if(-not $u){return""}
  if($u -like"http*"){$u}elseif($u.StartsWith("//")){"https:"+$u}elseif($u.StartsWith("/")){$b+$u}else{$b.TrimEnd('/')+"/"+$u.TrimStart('/')}}
function Head200{param($u)
  if(-not $u){return 0}
  try{(Invoke-WebRequest -Uri $u -Method Head -UseBasicParsing -TimeoutSec 10).StatusCode}catch{0}}

$results=@()
foreach($p in $pages){
  $u="$Base$p";Write-Log "Checking $u"
  $pg=Fetch $u
  $t=MatchVal $pg.Html "<title>(.*?)</title>"
  if(-not $t){$t=MatchVal $pg.Html "<meta[^>]+property=['""]og:title['""][^>]+content=['""](.*?)['""]"}
  $d=MatchVal $pg.Html "<meta[^>]+name=['""]description['""][^>]+content=['""](.*?)['""]"
  $ogt=MatchVal $pg.Html "<meta[^>]+property=['""]og:title['""][^>]+content=['""](.*?)['""]"
  $ogd=MatchVal $pg.Html "<meta[^>]+property=['""]og:description['""][^>]+content=['""](.*?)['""]"
  $ogi=MatchVal $pg.Html "<meta[^>]+property=['""]og:image['""][^>]+content=['""](.*?)['""]"
  $can=MatchVal $pg.Html "<link[^>]+rel=['""]canonical['""][^>]+href=['""](.*?)['""]"

  $tLen=if($t){$t.Length}else{0};$dLen=if($d){$d.Length}else{0}
  $tOK=($tLen -ge 10 -and $tLen -le 70);$dOK=($dLen -ge 50 -and $dLen -le 160)
  $ogiAbs=AbsUrl $ogi $Base;$ogiStatus=Head200 $ogiAbs

  $canOK=$false
  if($can){try{$canHost=([uri](AbsUrl $can $Base)).Host;$baseHost=([uri]$Base).Host;$canOK=($canHost -eq $baseHost)}catch{$canOK=$false}}

  $results+=[pscustomobject]@{
    Path=$p;Status=$pg.Status;OK=$pg.OK;TookMs=$pg.TookMs;
    Title=$t;TitleLen=$tLen;TitleOK=$tOK;
    Desc=$d;DescLen=$dLen;DescOK=$dOK;
    OGTitle=$ogt;OGDescription=$ogd;OGImage=$ogiAbs;OGStatus=$ogiStatus;
    Canonical=$can;CanonOK=$canOK
  }
}

$extra=@()
foreach($x in $extras){$r=Fetch "$Base$x";$extra+=[pscustomobject]@{Path=$x;Status=$r.Status;OK=$r.OK;TookMs=$r.TookMs}}

$report=[pscustomobject]@{Phase="Phase142-SEO-Tags-Verify";Base=$Base;Timestamp=(Get-Date).ToString("s");Pages=$results;Extras=$extra}
$report|ConvertTo-Json -Depth 6|Out-File $jsonFile -Encoding UTF8
Write-Log "Saved -> $jsonFile"

Write-Host "`nSummary:" -ForegroundColor Cyan
"{0,-16} {1,5} {2,5} {3,6} {4,7} {5,6} {6,7}" -f "Path","HTTP","OK","TLen","T ok?","DLen","D ok?"
foreach($r in $results){"{0,-16} {1,5} {2,5} {3,6} {4,7} {5,6} {6,7}" -f $r.Path,$r.Status,$r.OK,$r.TitleLen,$r.TitleOK,$r.DescLen,$r.DescOK|Write-Host}

Write-Host "`nOG image checks:" -ForegroundColor Cyan
"{0,-16} {1,-40} {2,6}" -f "Path","OG Image","HTTP"
foreach($r in $results){$og=if($r.OGImage){$r.OGImage}else{""};"{0,-16} {1,-40} {2,6}" -f $r.Path,$og,$r.OGStatus|Write-Host}

Write-Host "`nCanonical host consistency:" -ForegroundColor Cyan
"{0,-16} {1,-40} {2,8}" -f "Path","Canonical","HostOK"
foreach($r in $results){$can=if($r.Canonical){$r.Canonical}else{""};"{0,-16} {1,-40} {2,8}" -f $r.Path,$can,$r.CanonOK|Write-Host}

Write-Host "`nExtras:" -ForegroundColor Cyan
"{0,-16} {1,5} {2,5}" -f "Path","HTTP","OK"
foreach($r in $extra){"{0,-16} {1,5} {2,5}" -f $r.Path,$r.Status,$r.OK|Write-Host}

Write-Host "`nJSON report: $jsonFile"
Write-Host "Log saved:   $logFile`n"
Write-Host "Phase142 complete." -ForegroundColor Green
