<# =======================================================================
 Phase137-Postfix-CachePurge.ps1  (Legacy Compatible)
 Purpose: Soft purge & warm key production routes after FinalBoardSync
 Compatible with PowerShell 5.x
 ======================================================================= #>

#region Safety & Setup
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Prevent running from system32
$cwd = (Get-Location).Path
if ($cwd -match '\\Windows\\System32$') {
  Write-Host "❌ Do not run from system32. cd to your project folder (e.g., C:\Users\MR.NELSON\Downloads\truvern) and retry." -ForegroundColor Red
  exit 1
}

# Use script directory as working dir
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if ($ScriptDir) { Set-Location $ScriptDir }

$ts = Get-Date -Format "yyyyMMdd-HHmmss"
$logsDir = Join-Path $pwd "logs"
$reportsDir = Join-Path $pwd "reports"
$artifactsDir = Join-Path $pwd "artifacts\phase137-$ts"
New-Item -ItemType Directory -Force -Path $logsDir,$reportsDir,$artifactsDir | Out-Null

$logFile = Join-Path $logsDir "Phase137-Postfix-CachePurge-$ts.log"
$jsonFile = Join-Path $reportsDir "Phase137-Postfix-CachePurge-$ts.json"

function Write-Log {
  param([string]$msg,[string]$level="INFO")
  $line = "[{0}] [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $level, $msg
  $line | Tee-Object -FilePath $logFile -Append
}

Write-Log "=== Phase137: Postfix Cache Purge & Warm ==="
#endregion

#region Resolve APP_URL -> default truvern.com
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

#region Browser (for screenshots)
$EdgePaths = @(
  "$env:ProgramFiles (x86)\Microsoft\Edge\Application\msedge.exe",
  "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
) | Where-Object { Test-Path $_ }
$ChromePaths = @(
  "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
  "$env:ProgramFiles (x86)\Google\Chrome\Application\chrome.exe"
) | Where-Object { Test-Path $_ }
$BrowserExe = $null; $BrowserKind = $null
if ($EdgePaths.Count -gt 0) { $BrowserExe = $EdgePaths[0]; $BrowserKind="edge" }
elseif ($ChromePaths.Count -gt 0) { $BrowserExe = $ChromePaths[0]; $BrowserKind="chrome" }
if ($BrowserExe) { Write-Log "Headless browser: $BrowserKind at $BrowserExe" } else { Write-Log "No browser found for screenshots." "WARN" }

function Take-Screenshot {
  param([string]$Url, [string]$OutPath)
  if (-not $BrowserExe) { return $false }
  try {
    & $BrowserExe --headless=new --disable-gpu --window-size=1280,800 "--screenshot=$OutPath" "$Url" | Out-Null
    return (Test-Path $OutPath)
  } catch { return $false }
}
#endregion

#region Warm/Purge helper (fixed for PS5)
function Warm-Endpoint {
  param(
    [string]$Base,
    [string]$Endpoint,
    [int]$TimeoutSec = 25,
    [int]$Retries = 2
  )

  # Build unique URI safely for PS5
  $q = "v=" + [guid]::NewGuid().ToString("N")
  if ($Endpoint -like "*?*") {
    $uri = "$Base$Endpoint&$q"
  } else {
    $uri = "$Base$Endpoint?$q"
  }

  $attempt = 0; $ok = $false; $status = 0; $ms = 0; $err = $null
  while ($attempt -le $Retries -and -not $ok) {
    $attempt++
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
      $resp = Invoke-WebRequest -Uri $uri -Method GET -UseBasicParsing -TimeoutSec $TimeoutSec -Headers @{
        'Cache-Control'='no-cache, no-store, must-revalidate'
        'Pragma'='no-cache'
        'Expires'='0'
      }
      $sw.Stop(); $ms = [int]$sw.ElapsedMilliseconds
      $status = [int]$resp.StatusCode
      $ok = ($status -ge 200 -and $status -lt 300)
      if (-not $ok) { $err = "HTTP $status" }
    } catch {
      $sw.Stop(); $ms = [int]$sw.ElapsedMilliseconds
      $status = 0; $err = $_.Exception.Message
      Start-Sleep -Milliseconds (300 * $attempt)
    }
  }

  return [pscustomobject]@{
    Url       = $uri
    Endpoint  = $Endpoint
    Status    = $status
    OK        = $ok
    TookMs    = $ms
    Error     = $err
    Timestamp = (Get-Date).ToString("s")
  }
}
#endregion

#region Run targets
$targets = @(
  "/",
  "/api/health",
  "/trust-network",
  "/reports/board",
  "/vendors"
)

Write-Log "Warming & cache-busting on $ProdBase ..."
$results = @()
foreach ($ep in $targets) {
  $r = Warm-Endpoint -Base $ProdBase -Endpoint $ep
  $results += $r
  $tick = if ($r.OK) { "✅" } else { "⚠️" }
  Write-Log ("{0} {1,-20} -> {2} ({3} ms)" -f $tick, $ep, ($r.Status -as [string]), $r.TookMs)
}
#endregion

#region Screenshots
$s1 = Join-Path $artifactsDir "board-$ts.png"
$s2 = Join-Path $artifactsDir "trust-network-$ts.png"
if ($BrowserExe) {
  if (Take-Screenshot -Url ($ProdBase + "/reports/board") -OutPath $s1) {
    Write-Log "Saved screenshot -> $s1"
  } else { Write-Log "Screenshot failed for /reports/board" "WARN" }
  if (Take-Screenshot -Url ($ProdBase + "/trust-network") -OutPath $s2) {
    Write-Log "Saved screenshot -> $s2"
  } else { Write-Log "Screenshot failed for /trust-network" "WARN" }
}
#endregion

#region Save JSON + summary
$summary = [pscustomobject]@{
  Phase     = "Phase137-Postfix-CachePurge"
  Base      = $ProdBase
  Timestamp = (Get-Date).ToString("s")
  Results   = $results
  Artifacts = (Get-ChildItem $artifactsDir -File | Select-Object -ExpandProperty FullName)
}
$summary | ConvertTo-Json -Depth 6 | Out-File -FilePath $jsonFile -Encoding UTF8
Write-Log "JSON report -> $jsonFile"

Write-Host ""
Write-Host "Results:" -ForegroundColor Cyan
"{0,-20} {1,6} {2,6} {3,8}" -f "Endpoint","Status","OK","TookMs"
$results | ForEach-Object {
  "{0,-20} {1,6} {2,6} {3,8}" -f $_.Endpoint, $_.Status, $_.OK, $_.TookMs
} | Write-Host

Write-Host ""
Write-Host ("JSON report: {0}" -f $jsonFile)
Write-Host ("Log saved:   {0}" -f $logFile)
Write-Host ("Artifacts:   {0}" -f $artifactsDir)
Write-Host ""
Write-Host "Phase137 complete." -ForegroundColor Green
#endregion
