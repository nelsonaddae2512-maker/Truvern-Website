# ============================
# Phase121i-DomainVerifyFinal.ps1
# Verifies Vercel scope, domain ownership, aliasing, and HTTP 200s.
# ============================

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# --- Project/Safety: always run from script folder (avoid system32)
try {
  $here = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
  Set-Location $here
} catch { }

# --- Config
$TEAM   = 'nelson-addaes-projects'
$DOMAIN = 'truvern.com'
$DEPLOY_HINT = 'truvern-bmp5lwypy-nelson-addaes-projects.vercel.app'  # expected current prod deployment

# --- Logging
New-Item -ItemType Directory -Force -Path '.\logs' | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$LOG   = ".\logs\phase121i-domainverifyfinal-$stamp.log"
function Log($msg){ $msg | Tee-Object -FilePath $LOG -Append }

Log "=== Phase121i Domain Verify (team=$TEAM, domain=$DOMAIN) @ $stamp ==="

# --- Pre-check: Vercel CLI
try {
  $ver = (vercel --version)
  Log "Vercel CLI: $ver"
} catch {
  Log "ERROR: Vercel CLI not available. Please install 'vercel' and login."
  Read-Host "Press Enter to close"
  exit 1
}

# --- Who am I
try {
  $who = (vercel whoami)
  Log "whoami: $who"
} catch {
  Log "WARN: 'vercel whoami' failed (continuing): $($_.Exception.Message)"
}

# --- Domain ownership under correct team
Log "`n-- Domains in scope: $TEAM --"
$domainsOk = $false
try {
  $domList = vercel domains ls --scope $TEAM
  $domList | ForEach-Object { Log $_ }
  if ($domList -match [Regex]::Escape($DOMAIN)) { $domainsOk = $true }
} catch {
  Log "ERROR: 'vercel domains ls' failed: $($_.Exception.Message)"
}

# --- Deployment list (sanity)
Log "`n-- Deployments matching 'truvern' in scope: $TEAM --"
$lsOk = $false
try {
  $depList = vercel ls truvern --scope $TEAM
  $depList | ForEach-Object { Log $_ }
  if ($depList -match [Regex]::Escape($DEPLOY_HINT)) { $lsOk = $true }
} catch {
  Log "WARN: 'vercel ls truvern' failed: $($_.Exception.Message)"
}

# --- Alias list (log for audit)
Log "`n-- Aliases (scope: $TEAM) --"
try {
  $aliasList = vercel alias ls --scope $TEAM
  $aliasList | ForEach-Object { Log $_ }
} catch {
  Log "WARN: 'vercel alias ls' failed: $($_.Exception.Message)"
}

# --- HTTP checks
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
    $resp = Invoke-WebRequest -Uri $u -Method GET -MaximumRedirection 5 -TimeoutSec 30
    Log ("{0} -> {1}" -f $u, $resp.StatusCode)
    if ($resp.StatusCode -ne 200) { $all200 = $false }
  } catch {
    Log ("{0} -> FAIL: {1}" -f $u, $_.Exception.Message)
    $all200 = $false
  }
}

# --- Summary
Log "`n=== Summary ==="
Log ("Domain owned by team '{0}': {1}" -f $TEAM, ($(if($domainsOk){"YES"}else{"NO"})))
Log ("Deployment hint present ('{0}'): {1}" -f $DEPLOY_HINT, ($(if($lsOk){"YES"}else{"NO"})))
Log ("All key routes HTTP 200: {0}" -f ($(if($all200){"YES"}else{"NO"})))
Log "`nLog saved: $LOG"

Write-Host "`nDone. Full log: $LOG"
Read-Host "Press Enter to close"
