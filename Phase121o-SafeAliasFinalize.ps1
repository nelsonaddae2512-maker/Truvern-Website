# ==========================================
# Phase121o-SafeAliasFinalize.ps1 (Safe)
# Finalize alias -> newest Production deployment + verify 200s
# ==========================================

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# --- Config ---
$TEAM   = 'nelson-addaes-projects'
$PROJECT = 'truvern'
$DOMAIN = 'truvern.com'

# --- Force correct working directory ---
$projectPath = "C:\Users\MR.NELSON\Downloads\truvern"
if ((Get-Location).Path -ne $projectPath) { Set-Location $projectPath }

# --- Logging ---
New-Item -ItemType Directory -Force -Path '.\logs' | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$LOG   = ".\logs\phase121o-safealiasfinalize-$stamp.log"
function Log($m){ $m | Tee-Object -FilePath $LOG -Append }

Log "=== Phase121o SafeAliasFinalize @ $stamp ==="
Log "Team: $TEAM | Project: $PROJECT | Domain: $DOMAIN"
# --- Detect Vercel CLI absolute path (for ProcessStart) ---
$vercelPath = "C:\Users\MR.NELSON\AppData\Roaming\npm\vercel.cmd"
if (-not (Test-Path $vercelPath)) {
  # fallback for global PATH installs
  $vercelPath = (Get-Command vercel).Source
}
Log "Using Vercel CLI path: $vercelPath"

# --- Helper: get newest Production, Ready deployment URL ---
function Get-LatestDeploymentUrl {
  param([string]$team,[string]$project)

  Log "Fetching latest deployment list..."
  try {
    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = $vercelPath
    $processInfo.Arguments = "ls $project --scope $team"
    $processInfo.RedirectStandardOutput = $true
    $processInfo.RedirectStandardError = $true
    $processInfo.UseShellExecute = $false
    $processInfo.CreateNoWindow = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $processInfo
    $process.Start() | Out-Null
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    $output = ($stdout + "`n" + $stderr) -split "`n"
  }
  catch {
    Log "ERROR: Failed to run vercel ls: $($_.Exception.Message)"
    return $null
  }

  $output | ForEach-Object { Log $_ }

  # Prefer Ready + Production
  $prodLines = $output | Where-Object { ($_ -match 'Production') -and ($_ -match 'Ready') -and ($_ -match 'https?://[a-z0-9\-]+\.vercel\.app') }
  if ($prodLines) {
    $m = [regex]::Match(($prodLines | Select-Object -First 1), 'https?://([a-z0-9\-]+\.vercel\.app)')
    if ($m.Success) { return $m.Groups[1].Value }
  }

  # Fallback: first URL
  foreach ($ln in $output) {
    $m = [regex]::Match($ln, 'https?://([a-z0-9\-]+\.vercel\.app)')
    if ($m.Success) { return $m.Groups[1].Value }
  }

  return $null
}

# --- Detect latest deployment ---
$deploy = Get-LatestDeploymentUrl -team $TEAM -project $PROJECT
if (-not $deploy) {
  Log "ERROR: Could not detect a deployment URL for $PROJECT in $TEAM."
  Write-Host "No deployment found. See log: $LOG"
  Read-Host "Press Enter to close"
  exit 1
}
Log "Target deployment detected: $deploy"

# --- Alias setup ---
try {
  Log "`nAliasing apex ($DOMAIN) -> $deploy"
  vercel alias set $deploy $DOMAIN --scope $TEAM | ForEach-Object { Log $_ }
} catch { Log "WARN: Apex alias failed: $($_.Exception.Message)" }

try {
  Log "Aliasing www.$DOMAIN -> $deploy"
  vercel alias set $deploy "www.$DOMAIN" --scope $TEAM | ForEach-Object { Log $_ }
} catch { Log "WARN: WWW alias failed: $($_.Exception.Message)" }

# --- Show aliases ---
Log "`n-- Current aliases (scope: $TEAM) --"
try { vercel alias ls --scope $TEAM | ForEach-Object { Log $_ } } catch { Log "WARN: alias ls failed: $($_.Exception.Message)" }

# --- Verify HTTP 200 for core routes ---
$urls = @(
  "https://$DOMAIN/",
  "https://$DOMAIN/trust-network",
  "https://$DOMAIN/vendors",
  "https://$DOMAIN/reports/board"
)
Log "`n-- HTTP 200 verification --"
$all200 = $true
foreach ($u in $urls) {
  try {
    $r = Invoke-WebRequest -Uri $u -Method GET -MaximumRedirection 5 -TimeoutSec 30
    Log ("{0} -> {1}" -f $u, $r.StatusCode)
    if ($r.StatusCode -ne 200) { $all200 = $false }
  } catch {
    Log ("{0} -> FAIL: {1}" -f $u, $_.Exception.Message)
    $all200 = $false
  }
}

# --- Summary ---
Log "`n=== Summary ==="
Log ("Deployment set for alias: {0}" -f $deploy)
Log ("All key routes HTTP 200: {0}" -f ($(if($all200){"YES"}else{"NO"})))
Log ("Log saved: {0}" -f $LOG)

# --- Final confirmation ---
if ($all200) {
  Write-Host "`n✅ Alias finalized successfully for $DOMAIN ($deploy)" -ForegroundColor Green
  [console]::beep(800,200)
} else {
  Write-Host "`n⚠️  Alias finalized but one or more routes failed HTTP 200. Check $LOG." -ForegroundColor Yellow
  [console]::beep(500,300)
}

Write-Host "`nDone. Full log: $LOG"
Read-Host "Press Enter to close"
