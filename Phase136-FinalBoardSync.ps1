<# =======================================================================
 Phase136-FinalBoardSync.ps1
 Purpose: Final cache warm + verification for production board & dashboards
 Compatible with PowerShell 5.x
 ======================================================================= #>

#region Safety & Setup
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Prevent running from system32
$cwd = (Get-Location).Path
if ($cwd -match '\\Windows\\System32$') {
  Write-Host "❌ Do not run from system32. Please cd into your project folder (e.g., C:\Users\MR.NELSON\Downloads\truvern) and run again." -ForegroundColor Red
  exit 1
}

# Resolve project root to the script location
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if ($ScriptDir) { Set-Location $ScriptDir }

$ts = Get-Date -Format "yyyyMMdd-HHmmss"
$logsDir = Join-Path $pwd "logs"
$reportsDir = Join-Path $pwd "reports"
$artifactsDir = Join-Path $pwd "artifacts\phase136-$ts"
New-Item -ItemType Directory -Force -Path $logsDir,$reportsDir,$artifactsDir | Out-Null

$logFile = Join-Path $logsDir "Phase136-FinalBoardSync-$ts.log"
$jsonFile = Join-Path $reportsDir "Phase136-FinalBoardSync-$ts.json"

function Write-Log {
  param([string]$msg,[string]$level="INFO")
  $line = "[{0}] [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $level, $msg
  $line | Tee-Object -FilePath $logFile -Append
}

Write-Log "=== Phase136: Final Board Sync & Verify ==="
#endregion

#region APP_URL resolution
function Get-EnvValue($path, $key) {
  if (Test-Path $path) {
    $line = (Select-String -Path $path -Pattern "^\s*$key\s*=" -SimpleMatch | Select-Object -First 1).Line
    if ($line) {
      return ($line -split "=",2)[1].Trim().Trim("'`"")
    }
  }
  return $null
}

$envLocal = Join-Path $pwd ".env.local"
$envFile  = Join-Path $pwd ".env"

$appUrl = $null
if (-not $appUrl) { $appUrl = Get-EnvValue $envLocal "APP_URL" }
if (-not $appUrl) { $appUrl = Get-EnvValue $envFile  "APP_URL" }
if (-not $appUrl) { $appUrl = "https://truvern.com" }

# Trim trailing slash
if ($appUrl.EndsWith("/")) { $appUrl = $appUrl.TrimEnd("/") }

Write-Log "APP_URL resolved to: $appUrl"
if ($appUrl -ne "https://truvern.com") {
  Write-Log "Warning: APP_URL is not https://truvern.com. Continuing but prod checks use truvern.com." "WARN"
}

$ProdBase = "https://truvern.com"
#endregion

#region Browser detection
$EdgePaths = @(
  "$env:ProgramFiles (x86)\Microsoft\Edge\Application\msedge.exe",
  "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
) | Where-Object { Test-Path $_ }

$ChromePaths = @(
  "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
  "$env:ProgramFiles (x86)\Google\Chrome\Application\chrome.exe"
) | Where-Object { Test-Path $_ }

$BrowserExe = $null
$BrowserKind = $null
if ($EdgePaths.Count -gt 0) { $BrowserExe = $EdgePaths[0]; $BrowserKind="edge" }
elseif ($ChromePaths.Count -gt 0) { $BrowserExe = $ChromePaths[0]; $BrowserKind="chrome" }

if ($BrowserExe) {
  Write-Log "Headless browser detected: $BrowserKind at $BrowserExe"
} else {
  Write-Log "No Edge/Chrome detected for screenshots; skipping screenshot step." "WARN"
}
#endregion

#region HTTP helper
function Test-Endpoint {
  param(
    [string]$Base,
    [string]$Endpoint = "/",
    [int]$TimeoutSec = 25,
    [int]$Retries = 2
  )
  $uri = "$Base$Endpoint"
  $attempt = 0
  $ok = $false
  $status = 0
  $errorMsg = $null
  $ms = 0

  while ($attempt -le $Retries -and -not $ok) {
    $attempt++
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
      $resp = Invoke-WebRequest -Uri $uri -Method GET -UseBasicParsing -TimeoutSec $TimeoutSec -Headers @{ 'Cache-Control'='no-cache' }
      $sw.Stop()
      $ms = [int]$sw.ElapsedMilliseconds
      $status = [int]$resp.StatusCode
      $ok = ($status -ge 200 -and $status -lt 300)
      if (-not $ok) { $errorMsg = "HTTP $status" }
    } catch {
      $sw.Stop()
      $ms = [int]$sw.ElapsedMilliseconds
      $status = 0
      $errorMsg = $_.Exception.Message
      Start-Sleep -Milliseconds (300 * $attempt)
    }
  }

  return [pscustomobject]@{
    Base      = $Base
    Endpoint  = $Endpoint
    Url       = $uri
    Status    = $status
    OK        = $ok
    TookMs    = $ms
    Error     = $errorMsg
    Timestamp = (Get-Date).ToString("s")
  }
}
#endregion

#region Endpoints
$targets = @(
  "/",
  "/api/health",
  "/trust-network",
  "/reports/board",
  "/vendors",
  "/api/board.csv"
)
#endregion

#region Run checks
Write-Log "Checking base: $ProdBase"
$results = @()
foreach ($ep in $targets) {
  $r = Test-Endpoint -Base $ProdBase -Endpoint $ep
  $results += $r
  $emoji = if ($r.OK) { "✅" } else { "⚠️" }
  Write-Log ("{0} {1,-28} -> {2} ({3} ms)" -f $emoji, $ep, ($r.Status -as [string]), $r.TookMs)
}
#endregion

#region Artifact capture
# Board HTML
$boardOk = $results | Where-Object { $_.Endpoint -eq "/reports/board" } | Select-Object -First 1
if ($boardOk -and $boardOk.OK) {
  try {
    $html = Invoke-WebRequest -Uri ($ProdBase + "/reports/board?v=$ts") -UseBasicParsing -TimeoutSec 30
    $htmlPath = Join-Path $artifactsDir "board-$ts.html"
    $html.Content | Out-File -FilePath $htmlPath -Encoding UTF8
    Write-Log "Saved board HTML -> $htmlPath"
  } catch { Write-Log "Failed to save board HTML: $($_.Exception.Message)" "WARN" }
}

# CSV
$csvRes = $results | Where-Object { $_.Endpoint -eq "/api/board.csv" } | Select-Object -First 1
if ($csvRes -and $csvRes.Status -eq 200) {
  try {
    $csvPath = Join-Path $artifactsDir "board-$ts.csv"
    Invoke-WebRequest -Uri ($ProdBase + "/api/board.csv?v=$ts") -OutFile $csvPath -TimeoutSec 30 | Out-Null
    Write-Log "Saved board CSV -> $csvPath"
  } catch { Write-Log "Failed to save board CSV: $($_.Exception.Message)" "WARN" }
} else {
  Write-Log "No board CSV endpoint detected (200). Skipping CSV artifact." "WARN"
}

# Screenshot
function Take-Screenshot {
  param([string]$Url, [string]$OutPath)
  if (-not $BrowserExe) { return $false }
  try {
    if ($BrowserKind -eq "edge") {
      & $BrowserExe --headless --disable-gpu --window-size=1280,800 "--screenshot=$OutPath" "$Url" | Out-Null
    } else {
      & $BrowserExe --headless --disable-gpu --window-size=1280,800 "--screenshot=$OutPath" "$Url" | Out-Null
    }
    return (Test-Path $OutPath)
  } catch { return $false }
}

$s1 = Join-Path $artifactsDir "board-$ts.png"
$s2 = Join-Path $artifactsDir "trust-network-$ts.png"

if ($BrowserExe) {
  if (Take-Screenshot -Url ($ProdBase + "/reports/board?v=$ts") -OutPath $s1) {
    Write-Log "Saved screenshot -> $s1"
  } else { Write-Log "Screenshot failed for /reports/board" "WARN" }

  if (Take-Screenshot -Url ($ProdBase + "/trust-network?v=$ts") -OutPath $s2) {
    Write-Log "Saved screenshot -> $s2"
  } else { Write-Log "Screenshot failed for /trust-network" "WARN" }
}
#endregion

#region Save JSON report
$summary = [pscustomobject]@{
  Phase       = "Phase136-FinalBoardSync"
  Timestamp   = (Get-Date).ToString("s")
  Base        = $ProdBase
  Results     = $results
  Artifacts   = (Get-ChildItem $artifactsDir -File | Select-Object -ExpandProperty FullName)
}

$summary | ConvertTo-Json -Depth 6 | Out-File -FilePath $jsonFile -Encoding UTF8
Write-Log "JSON report saved -> $jsonFile"

$failed = @($results | Where-Object { -not $_.OK -and $_.Endpoint -ne "/api/board.csv" })
if ($failed.Count -gt 0) {
  Write-Log ("Completed with {0} failing required checks." -f $failed.Count) "WARN"
} else {
  Write-Log "All required checks passed."
}

Write-Host ""
Write-Host "Results:" -ForegroundColor Cyan
"{0,-32} {1,6} {2,6} {3,8}" -f "Endpoint","Status","OK","TookMs"
$results | ForEach-Object {
  "{0,-32} {1,6} {2,6} {3,8}" -f $_.Endpoint, $_.Status, $_.OK, $_.TookMs
} | Write-Host

Write-Host ""
Write-Host ("JSON report: {0}" -f $jsonFile)
Write-Host ("Log saved:   {0}" -f $logFile)
Write-Host ("Artifacts:   {0}" -f $artifactsDir)
Write-Host ""
Write-Host "Phase136 complete." -ForegroundColor Green
#endregion
