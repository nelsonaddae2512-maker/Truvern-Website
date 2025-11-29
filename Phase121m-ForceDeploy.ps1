# ==============================
# Phase121m-ForceDeploy.ps1
# Force a fresh Production deploy to Vercel and verify it went live.
# ==============================

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# --- Config ---
$TEAM     = 'nelson-addaes-projects'
$PROJECT  = 'truvern'
$DOMAIN   = 'truvern.com'
$UsePrebuilt = $true   # set $false to let Vercel build remotely

# --- Always run from the script folder (not system32) ---
try { if ($PSScriptRoot) { Set-Location $PSScriptRoot } } catch {}

# --- Logging ---
New-Item -ItemType Directory -Force -Path '.\logs' | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$LOG   = ".\logs\phase121m-forcedeploy-$stamp.log"
function Log($m){ $m | Tee-Object -FilePath $LOG -Append }

Log "=== Phase121m ForceDeploy @ $stamp ==="
Log "Team: $TEAM | Project: $PROJECT | Domain: $DOMAIN"

# --- Vercel CLI presence ---
try { $vcVer = vercel --version; Log "Vercel CLI: $vcVer" } catch {
  Log "ERROR: Vercel CLI not installed. Install it and run 'vercel login'."
  Read-Host "Press Enter to close"; exit 1
}

# --- Auth / scope ---
try { $who = vercel whoami; Log "whoami: $who" } catch {
  Log "WARN: 'vercel whoami' failed: $($_.Exception.Message)"
}

# --- Ensure correct link (avoid wrong team bindings) ---
if (Test-Path .\.vercel) {
  $meta = Get-Content .\.vercel\project.json -ErrorAction SilentlyContinue | Out-String
  if ($meta -and ($meta -match '"orgId"') -and ($meta -match 'nelson-ai-projects')) {
    Log "Stale .vercel link found (old team). Re-linking…"
    Remove-Item -Recurse -Force .\.vercel
  }
}

if (-not (Test-Path .\.vercel)) {
  Log "Linking folder to $TEAM/$PROJECT…"
  # Non-interactive link: try existing project name under team
  try {
    vercel link --yes --project $PROJECT --scope $TEAM | ForEach-Object { Log $_ }
  } catch {
    Log "WARN: direct link failed, falling back to interactive defaults: $($_.Exception.Message)"
    vercel link --scope $TEAM | ForEach-Object { Log $_ }
  }
}

# --- Pull production env for local build parity ---
try {
  Log "Pulling production env…"
  vercel pull --yes --environment=production --scope $TEAM | ForEach-Object { Log $_ }
} catch { Log "WARN: 'vercel pull' failed (continuing): $($_.Exception.Message)" }

# --- Install deps ---
function RunStep($cmd) {
  Log "`n$cmd"
  # Run command via cmd but don't treat stderr as fatal
  $processInfo = New-Object System.Diagnostics.ProcessStartInfo
  $processInfo.FileName = "cmd.exe"
  $processInfo.Arguments = "/c $cmd"
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

  # Log everything but don’t throw unless actual failure
  ($stdout + "`n" + $stderr) | Tee-Object -FilePath $LOG -Append | Out-Host

  if ($process.ExitCode -ne 0) {
    throw "Command failed ($($process.ExitCode)): $cmd"
  }
}

# Prefer pnpm if available, else npm
$havePnpm = (Get-Command pnpm -ErrorAction SilentlyContinue) -ne $null
if ($havePnpm) {
if (Test-Path ".\pnpm-lock.yaml") {
    if (Test-Path ".\pnpm-lock.yaml") {
    RunStep "pnpm install --frozen-lockfile"
} else {
    Log "pnpm-lock.yaml not found — running relaxed install..."
    RunStep "pnpm install --no-frozen-lockfile"
}
} else {
    RunStep "pnpm install --no-frozen-lockfile"
}
  RunStep "pnpm run build"
} else {
  RunStep "npm ci"
  RunStep "npm run build"
}

# --- Deploy to Production ---
$deployCmd = if ($UsePrebuilt) {
  "vercel deploy --prod --confirm --prebuilt --scope $TEAM"
} else {
  "vercel deploy --prod --confirm --scope $TEAM"
}
Log "`nDeploying to Production…"
$deployOutput = & powershell -NoProfile -Command $deployCmd 2>&1 | Tee-Object -FilePath $LOG -Append
if ($LASTEXITCODE -ne 0) { throw "Vercel deploy failed." }

# Extract deployment URL
$deploymentUrl = ($deployOutput | Select-String -Pattern 'https?://[a-z0-9\-]+\.vercel\.app' -AllMatches).Matches.Value | Select-Object -Last 1
if (-not $deploymentUrl) { Log "WARN: Could not detect deployment URL from output."; }
else { Log "New deployment: $deploymentUrl" }

# --- Alias to apex + www ---
if ($deploymentUrl) {
  try {
    Log "Aliasing $DOMAIN -> $deploymentUrl"
    vercel alias set $deploymentUrl $DOMAIN --scope $TEAM | ForEach-Object { Log $_ }
  } catch { Log "WARN: apex alias: $($_.Exception.Message)" }
  try {
    Log "Aliasing www.$DOMAIN -> $deploymentUrl"
    vercel alias set $deploymentUrl "www.$DOMAIN" --scope $TEAM | ForEach-Object { Log $_ }
  } catch { Log "WARN: www alias: $($_.Exception.Message)" }
}

# --- Verify HTTP 200s ---
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

# --- Show recent deployments (audit) ---
Log "`n-- Recent deployments for $PROJECT (scope: $TEAM) --"
try { vercel ls $PROJECT --scope $TEAM | ForEach-Object { Log $_ } } catch { Log "WARN: vercel ls: $($_.Exception.Message)" }

# --- Summary ---
Log "`n=== Summary ==="

# Safe fallback for deployment URL
if (-not $deploymentUrl -or $deploymentUrl -eq "") { $deploymentUrl = "(unknown)" }

Log ("Deployment URL: {0}" -f $deploymentUrl)
if ($all200) {
    Log ("All key routes HTTP 200: YES")
} else {
    Log ("All key routes HTTP 200: NO")
}

Log ("Log saved: {0}" -f $LOG)

Write-Host "`nDone. Full log: $LOG"
Read-Host "Press Enter to close"
