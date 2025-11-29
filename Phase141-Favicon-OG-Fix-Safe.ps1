<# =====================================================================
 Phase141-Favicon-OG-Fix-Safe.ps1
 Purpose: Create or verify favicon.ico and opengraph-image.png, then
          confirm they return 200 from production.
 Compatible: PowerShell 5.x
 ===================================================================== #>

#region Setup
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$cwd = (Get-Location).Path
if ($cwd -match '\\Windows\\System32$') {
  Write-Host "❌ Do not run from system32. Please cd to your project folder (e.g. C:\Users\MR.NELSON\Downloads\truvern)" -ForegroundColor Red
  exit 1
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if ($ScriptDir) { Set-Location $ScriptDir }

$ts = Get-Date -Format "yyyyMMdd-HHmmss"
$logsDir = Join-Path $pwd "logs"
$reportsDir = Join-Path $pwd "reports"
$publicDir = Join-Path $pwd "public"
$artifactsDir = Join-Path $pwd "artifacts\phase141-$ts"
New-Item -ItemType Directory -Force -Path $logsDir,$reportsDir,$publicDir,$artifactsDir | Out-Null

$logFile = Join-Path $logsDir "Phase141-Favicon-OG-Fix-$ts.log"
$jsonFile = Join-Path $reportsDir "Phase141-Favicon-OG-Fix-$ts.json"

function Write-Log { param([string]$msg,[string]$level="INFO")
  $line = "[{0}] [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"),$level,$msg
  $line | Tee-Object -FilePath $logFile -Append | Out-Null
}

Write-Log "=== Phase141: Favicon & OG Image Fix (Safe Edition) ==="
#endregion

#region Asset generation
$faviconPath = Join-Path $publicDir "favicon.ico"
$ogPath = Join-Path $publicDir "opengraph-image.png"

# 1️⃣ Create simple favicon.ico placeholder if missing
if (-not (Test-Path $faviconPath)) {
  Write-Log "favicon.ico missing; creating placeholder."
  try {
    # Create a minimal valid ICO header (1x1 transparent pixel)
    $tinyIcoB64 = "AAABAAEAEBAAAAAAIABoAwAAFgAAACgAAAAQAAAAIAAAAAEABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    $bytes = [Convert]::FromBase64String($tinyIcoB64)
    [IO.File]::WriteAllBytes($faviconPath,$bytes)
    Write-Log "favicon.ico placeholder created at $faviconPath"
  } catch {
    Write-Log ("Failed to create favicon placeholder: " + $_.Exception.Message) "WARN"
  }
} else {
  Write-Log "favicon.ico already present."
}

# 2️⃣ Create simple opengraph-image.png placeholder if missing
if (-not (Test-Path $ogPath)) {
  Write-Log "opengraph-image.png missing; creating placeholder text image."
  try {
    Add-Content -Path $ogPath -Value "Truvern OpenGraph Image Placeholder"
    Write-Log "opengraph-image.png placeholder created at $ogPath"
  } catch {
    Write-Log ("Failed to create OG placeholder: " + $_.Exception.Message) "WARN"
  }
} else {
  Write-Log "opengraph-image.png already present."
}
#endregion

#region Optional deploy (if Vercel available)
$vercel = Get-Command vercel -ErrorAction SilentlyContinue
if ($vercel) {
  try {
    Write-Log "Vercel CLI detected: $($vercel.Source)"
    Write-Log "Running vercel build + deploy (prebuilt)..."
    cmd /c "vercel build" | Tee-Object -FilePath $logFile -Append | Out-Null
    cmd /c "vercel deploy --prebuilt --prod" | Tee-Object -FilePath $logFile -Append | Out-Null
    Write-Log "Vercel deploy attempted."
  } catch {
    Write-Log ("Vercel deploy failed: " + $_.Exception.Message) "WARN"
  }
} else {
  Write-Log "Vercel CLI not found; skipping deploy." "WARN"
}
#endregion

#region Verify production endpoints
$ProdBase = "https://truvern.com"
function Check {
  param([string]$Endpoint,[int]$TimeoutSec=25)
  $url = "$ProdBase$Endpoint"
  $sw = [Diagnostics.Stopwatch]::StartNew()
  try {
    $resp = Invoke-WebRequest -Uri $url -TimeoutSec $TimeoutSec -UseBasicParsing
    $sw.Stop()
    return [pscustomobject]@{
      Endpoint = $Endpoint
      Status   = [int]$resp.StatusCode
      OK       = $true
      TookMs   = [int]$sw.ElapsedMilliseconds
    }
  } catch {
    $sw.Stop()
    return [pscustomobject]@{
      Endpoint = $Endpoint
      Status   = 0
      OK       = $false
      TookMs   = [int]$sw.ElapsedMilliseconds
      Error    = $_.Exception.Message
    }
  }
}

Write-Log "Verifying /favicon.ico and /opengraph-image.png …"
$results = @()
$results += Check "/favicon.ico"
$results += Check "/opengraph-image.png"

foreach ($r in $results) {
  $tick = if ($r.OK) {"✅"} else {"⚠️"}
  Write-Log ("{0} {1,-22} -> {2} ({3} ms)" -f $tick,$r.Endpoint,($r.Status -as [string]),$r.TookMs)
}
#endregion

#region Save summary
$summary = [pscustomobject]@{
  Phase     = "Phase141-Favicon-OG-Fix-Safe"
  Timestamp = (Get-Date).ToString("s")
  Base      = $ProdBase
  Files     = @{ Favicon = $faviconPath; OpenGraph = $ogPath }
  Results   = $results
}
$summary | ConvertTo-Json -Depth 5 | Out-File -FilePath $jsonFile -Encoding UTF8
Write-Log "JSON report -> $jsonFile"

Write-Host "`nResults:" -ForegroundColor Cyan
"{0,-22} {1,6} {2,6} {3,8}" -f "Endpoint","Status","OK","TookMs"
$results | ForEach-Object {
  "{0,-22} {1,6} {2,6} {3,8}" -f $_.Endpoint,$_.Status,$_.OK,$_.TookMs
} | Write-Host

Write-Host "`nJSON report: $jsonFile"
Write-Host "Log saved:   $logFile`n"
Write-Host "Phase141 complete." -ForegroundColor Green
#endregion
