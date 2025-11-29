<# =======================================================================
 Phase137b-HttpClientWarm.ps1
 Purpose: Reliable cache-bust + warm using .NET HttpClient (fixes Status 0)
 ======================================================================= #>

#region Safety & Setup
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$cwd = (Get-Location).Path
if ($cwd -match '\\Windows\\System32$') {
  Write-Host "❌ Do not run from system32. cd to C:\Users\MR.NELSON\Downloads\truvern" -ForegroundColor Red
  exit 1
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if ($ScriptDir) { Set-Location $ScriptDir }

$ts = Get-Date -Format "yyyyMMdd-HHmmss"
$logsDir = Join-Path $pwd "logs"
$reportsDir = Join-Path $pwd "reports"
$artifactsDir = Join-Path $pwd "artifacts\phase137b-$ts"
New-Item -ItemType Directory -Force -Path $logsDir,$reportsDir,$artifactsDir | Out-Null

$logFile = Join-Path $logsDir "Phase137b-HttpClientWarm-$ts.log"
$jsonFile = Join-Path $reportsDir "Phase137b-HttpClientWarm-$ts.json"

function Write-Log { param([string]$msg,[string]$level="INFO")
  ("[{0}] [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"),$level,$msg) |
    Tee-Object -FilePath $logFile -Append | Out-Null
}
Write-Log "=== Phase137b: HttpClient Cache Purge & Warm ==="
#endregion

#region Resolve APP_URL
function Get-EnvValue($path, $key) {
  if (Test-Path $path) {
    $line = (Select-String -Path $path -Pattern "^\s*$key\s*=" -SimpleMatch | Select-Object -First 1).Line
    if ($line) { return ($line -split "=",2)[1].Trim().Trim("'`"") }
  }
  return $null
}
$envLocal = Join-Path $pwd ".env.local"
$envFile  = Join-Path $pwd ".env"
$appUrl = $null
if (-not $appUrl) { $appUrl = Get-EnvValue $envLocal "APP_URL" }
if (-not $appUrl) { $appUrl = Get-EnvValue $envFile  "APP_URL" }
if (-not $appUrl) { $appUrl = "https://truvern.com" }
if ($appUrl.EndsWith("/")) { $appUrl = $appUrl.TrimEnd("/") }
$ProdBase = "https://truvern.com"
Write-Log "APP_URL: $appUrl | ProdBase: $ProdBase"
#endregion

#region Browser (optional screenshots)
$EdgePaths=@("$env:ProgramFiles (x86)\Microsoft\Edge\Application\msedge.exe","$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe") | ?{Test-Path $_}
$ChromePaths=@("$env:ProgramFiles\Google\Chrome\Application\chrome.exe","$env:ProgramFiles (x86)\Google\Chrome\Application\chrome.exe") | ?{Test-Path $_}
$BrowserExe=$null; $BrowserKind=$null
if($EdgePaths){$BrowserExe=$EdgePaths[0];$BrowserKind="edge"} elseif($ChromePaths){$BrowserExe=$ChromePaths[0];$BrowserKind="chrome"}
if($BrowserExe){Write-Log "Headless browser: $BrowserKind at $BrowserExe"} else {Write-Log "No browser for screenshots." "WARN"}

function Take-Screenshot { param([string]$Url,[string]$OutPath)
  if (-not $BrowserExe) { return $false }
  try { & $BrowserExe --headless=new --disable-gpu --window-size=1280,800 "--screenshot=$OutPath" "$Url" | Out-Null; Test-Path $OutPath } catch { $false }
}
#endregion

#region HttpClient helper
# Build a single static HttpClient to reuse connection
Add-Type -AssemblyName System.Net.Http | Out-Null
$handler = New-Object System.Net.Http.HttpClientHandler
$handler.AllowAutoRedirect = $true
$client  = New-Object System.Net.Http.HttpClient($handler)
$client.DefaultRequestHeaders.Add("User-Agent","Mozilla/5.0 (Windows NT 10.0) Truvern-Warm/1.0")
$client.Timeout = [TimeSpan]::FromSeconds(25)

function Warm-Endpoint {
  param([string]$Base,[string]$Endpoint,[int]$Retries=2)
  $q = "v=" + [guid]::NewGuid().ToString("N")
  $uri = if ($Endpoint -like "*?*") { "$Base$Endpoint&$q" } else { "$Base$Endpoint?$q" }

  $attempt=0; $ok=$false; $status=0; $ms=0; $err=$null
  while($attempt -le $Retries -and -not $ok){
    $attempt++
    $sw=[System.Diagnostics.Stopwatch]::StartNew()
    try{
      $req = New-Object System.Net.Http.HttpRequestMessage 'GET', $uri
      $req.Headers.CacheControl = New-Object System.Net.Http.Headers.CacheControlHeaderValue
      $req.Headers.CacheControl.NoCache = $true
      $req.Headers.CacheControl.NoStore = $true
      $resp = $client.SendAsync($req).Result
      $sw.Stop()
      $status = [int]$resp.StatusCode
      $ok = ($resp.IsSuccessStatusCode)
      # ensure body is read (warm)
      $null = ($resp.Content.ReadAsStringAsync().Result)
    } catch {
      $sw.Stop(); $status = 0; $err = $_.Exception.Message
      Start-Sleep -Milliseconds (300 * $attempt)
    }
    $ms=[int]$sw.ElapsedMilliseconds
  }

  [pscustomobject]@{ Url=$uri; Endpoint=$Endpoint; Status=$status; OK=$ok; TookMs=$ms; Error=$err; Timestamp=(Get-Date).ToString("s") }
}
#endregion

#region Targets & run
$targets = @("/","/api/health","/trust-network","/reports/board","/vendors")
Write-Log "Warming & cache-busting (HttpClient) on $ProdBase ..."
$results = @()
foreach($ep in $targets){
  $r = Warm-Endpoint -Base $ProdBase -Endpoint $ep
  $results += $r
  $tick = if ($r.OK) { "✅" } else { "⚠️" }
  $msg = "{0} {1,-20} -> {2} ({3} ms){4}" -f $tick,$ep,($r.Status -as [string]),$r.TookMs,($(if($r.Error){" | err: $($r.Error)"} else {""}))
  Write-Log $msg
}
#endregion

#region Screenshots
$s1 = Join-Path $artifactsDir "board-$ts.png"
$s2 = Join-Path $artifactsDir "trust-network-$ts.png"
if ($BrowserExe) {
  if (Take-Screenshot -Url ($ProdBase + "/reports/board") -OutPath $s1) { Write-Log "Saved screenshot -> $s1" } else { Write-Log "Screenshot failed for /reports/board" "WARN" }
  if (Take-Screenshot -Url ($ProdBase + "/trust-network") -OutPath $s2) { Write-Log "Saved screenshot -> $s2" } else { Write-Log "Screenshot failed for /trust-network" "WARN" }
}
#endregion

#region Save JSON + summary
$summary = [pscustomobject]@{
  Phase     = "Phase137b-HttpClientWarm"
  Base      = $ProdBase
  Timestamp = (Get-Date).ToString("s")
  Results   = $results
  Artifacts = (Get-ChildItem $artifactsDir -File | Select-Object -ExpandProperty FullName)
}
$summary | ConvertTo-Json -Depth 6 | Out-File -FilePath $jsonFile -Encoding UTF8
Write-Log "JSON report -> $jsonFile"

Write-Host "`nResults:" -ForegroundColor Cyan
"{0,-20} {1,6} {2,6} {3,8}" -f "Endpoint","Status","OK","TookMs"
$results | % { "{0,-20} {1,6} {2,6} {3,8}" -f $_.Endpoint,$_.Status,$_.OK,$_.TookMs } | Write-Host
Write-Host "`nJSON report: $jsonFile"
Write-Host "Log saved:   $logFile"
Write-Host "Artifacts:   $artifactsDir`n"
Write-Host "Phase137b complete." -ForegroundColor Green
#endregion
