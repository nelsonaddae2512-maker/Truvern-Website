<# =======================================================================
 Phase140-GoLive-Checklist.ps1
 Purpose: Final production readiness & live verification
 ======================================================================= #>

#region Setup
$ErrorActionPreference='Stop'
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
$ScriptDir=Split-Path -Parent $MyInvocation.MyCommand.Path
if($ScriptDir){Set-Location $ScriptDir}
$ts=Get-Date -Format "yyyyMMdd-HHmmss"
$logsDir=Join-Path $pwd "logs";$reportsDir=Join-Path $pwd "reports"
New-Item -ItemType Directory -Force -Path $logsDir,$reportsDir|Out-Null
$logFile=Join-Path $logsDir "Phase140-GoLive-$ts.log"
$jsonFile=Join-Path $reportsDir "Phase140-GoLive-$ts.json"
function Write-Log{param([string]$m,[string]$lvl="INFO")
  $l="[${(Get-Date -Format "yyyy-MM-dd HH:mm:ss")}] [$lvl] $m"
  $l|Tee-Object -FilePath $logFile -Append|Out-Null}
Write-Log "=== Phase140: GoLive Checklist ==="
#endregion

#region Base
$ProdBase="https://truvern.com"
Write-Log "Checking base: $ProdBase"
#endregion

#region Helper
function Fetch {
  param([string]$url,[int]$timeout=25)
  $sw=[Diagnostics.Stopwatch]::StartNew()
  try{
    $resp=Invoke-WebRequest -Uri $url -TimeoutSec $timeout -UseBasicParsing
    $sw.Stop()
    return [pscustomobject]@{
      Url=$url;Status=$resp.StatusCode;OK=$true;
      TookMs=[int]$sw.ElapsedMilliseconds;
      Length=$resp.Content.Length;
      Snippet=($resp.Content.Substring(0,[Math]::Min(150,$resp.Content.Length))).Trim()
    }
  }catch{
    $sw.Stop()
    return [pscustomobject]@{
      Url=$url;Status=0;OK=$false;TookMs=[int]$sw.ElapsedMilliseconds;
      Error=$_.Exception.Message
    }
  }
}
#endregion

#region Checks
$targets=@(
  "/",
  "/api/health",
  "/trust-network",
  "/reports/board",
  "/vendors",
  "/favicon.ico",
  "/sitemap.xml",
  "/robots.txt",
  "/opengraph-image.png"
)
Write-Log "Running final checks ..."
$results=@()
foreach($ep in $targets){
  $r=Fetch "$ProdBase$ep"
  $results+=$r
  $tick=if($r.OK){"✅"}else{"⚠️"}
  Write-Log ("{0} {1,-25} -> {2} ({3} ms)" -f $tick,$ep,($r.Status -as [string]),$r.TookMs)
}
#endregion

#region Simple HTML meta scan
try{
  $home=Invoke-WebRequest "$ProdBase" -UseBasicParsing -TimeoutSec 20
  $meta=$home.Content -match "og:title|og:description|meta name=`"description`""
  if($meta){Write-Log "OG/Meta tags detected ✅"}else{Write-Log "OG/Meta tags missing ⚠️" "WARN"}
}catch{Write-Log "Failed meta scan: $($_.Exception.Message)" "WARN"}
#endregion

#region Save summary
$summary=[pscustomobject]@{
  Phase="Phase140-GoLive-Checklist"
  Timestamp=(Get-Date).ToString("s")
  Base=$ProdBase
  Results=$results
}
$summary|ConvertTo-Json -Depth 5|Out-File -Encoding UTF8 $jsonFile
Write-Log "JSON report -> $jsonFile"

Write-Host "`nResults:" -ForegroundColor Cyan
"{0,-25} {1,6} {2,6} {3,8}" -f "Endpoint","Status","OK","TookMs"
$results|%{"{0,-25} {1,6} {2,6} {3,8}" -f $_.Url.Replace($ProdBase,''),$_.Status,$_.OK,$_.TookMs}|Write-Host
Write-Host "`nJSON report: $jsonFile"
Write-Host "Log saved:   $logFile`n"
Write-Host "Phase140 complete." -ForegroundColor Green
#endregion
