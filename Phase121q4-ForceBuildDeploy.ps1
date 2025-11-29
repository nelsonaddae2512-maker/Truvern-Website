# Phase121q4-ForceBuildDeploy.ps1 — no wrappers, no here-strings
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$projectPath = "C:\Users\MR.NELSON\Downloads\truvern"
if ((Get-Location).Path -ne $projectPath) { Set-Location $projectPath }

New-Item -ItemType Directory -Force -Path ".\logs" | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$LOG = ".\logs\phase121q4-$stamp.log"
function Log([string]$m){ $m | Tee-Object -FilePath $LOG -Append }

Log "=== Phase121q4 start @ $stamp ==="
Log "Project: $projectPath"

# 0) Sanity
if (-not (Test-Path ".\package.json")) { Log "ERROR: package.json missing"; throw "package.json missing" }

# 1) Install & build (prefer pnpm)
if (Get-Command pnpm -ErrorAction SilentlyContinue) {
  Log "Running: pnpm install --no-frozen-lockfile"
  pnpm install --no-frozen-lockfile 2>&1 | Tee-Object -FilePath $LOG -Append
  Log "Running: pnpm run build"
  pnpm run build 2>&1 | Tee-Object -FilePath $LOG -Append
} else {
  Log "Running: npm install"
  npm install 2>&1 | Tee-Object -FilePath $LOG -Append
  Log "Running: npm run build"
  npm run build 2>&1 | Tee-Object -FilePath $LOG -Append
}

# 2) Deploy to Production
Log "Running: vercel --prod (must already be linked/authenticated)"
$deployOut = vercel --prod 2>&1 | Tee-Object -FilePath $LOG -Append
# Try to capture the deployment URL from the output
$deploymentUrl = ($deployOut | Select-String -Pattern 'https?://[^\s]+' -AllMatches).Matches.Value |
  Where-Object { $_ -like '*.vercel.app' } | Select-Object -First 1

if ([string]::IsNullOrWhiteSpace($deploymentUrl)) {
  Log "WARN: Could not parse deployment URL from vercel output."
} else {
  Log "Deployment URL: $deploymentUrl"
}

# 3) Verify public routes on truvern.com
$urls = @(
  "https://truvern.com/",
  "https://truvern.com/trust-network",
  "https://truvern.com/vendors",
  "https://truvern.com/reports/board"
)

Log "--- HTTP 200 verification ---"
$all200 = $true
foreach($u in $urls){
  try {
    $r = Invoke-WebRequest -Uri $u -Method GET -MaximumRedirection 5 -TimeoutSec 25
    Log ("{0} -> {1}" -f $u, $r.StatusCode)
    if ($r.StatusCode -ne 200) { $all200 = $false }
  } catch {
    Log ("{0} -> FAIL: {1}" -f $u, $_.Exception.Message)
    $all200 = $false
  }
}

Log "=== Summary ==="
Log ("Deployment URL: {0}" -f ($deploymentUrl ?? "(unknown)"))
Log ("All key routes HTTP 200: {0}" -f ($(if($all200){"YES"}else{"NO"})))
Log ("Log saved: {0}" -f $LOG)
Write-Host "`nDone. Full log: $LOG"
