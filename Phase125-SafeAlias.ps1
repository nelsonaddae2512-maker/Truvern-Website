# Phase125: Safe alias -> truvern.com + www, then verify routes
# Requires: Linked .vercel (already linked to nelson-ai-projects/truvern)
# Works with Vercel CLI v48+

$ErrorActionPreference = 'Stop'

function Log {
  param([string]$msg, [ConsoleColor]$color = 'Gray')
  $ts = (Get-Date).ToString('HH:mm:ss')
  Write-Host "[$ts] $msg" -ForegroundColor $color
}

# ---------- Guard: not from system32 ----------
try { Set-Location (Get-Location) } catch {}
$PWD = (Get-Location).Path
if (Test-Path "C:\Windows\System32") {
  if ($PWD -match '\\Windows\\System32$') {
    Write-Host "? Do not run from System32. Please cd into your project folder and rerun." -ForegroundColor Red
    exit 1
  }
}

# ---------- Prep logs ----------
$stamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
$logDir = Join-Path $PWD 'logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$mainLog = Join-Path $logDir "phase125-alias-$stamp.log"
$vrfyLog = Join-Path $logDir "route-public-verify-$stamp.txt"

Log "=== Phase125: Safe alias -> verify ===" Cyan
Log "Logs: $mainLog" DarkGray

# ---------- Ensure vercel is resolvable ----------
if (-not (Get-Command vercel -ErrorAction SilentlyContinue)) {
  Log "vercel not on PATH; attempting to locate..." Yellow
  $vercelCmd = Get-ChildItem "$env:APPDATA\npm\vercel*.cmd" -ErrorAction SilentlyContinue |
               Select-Object -First 1
  if ($vercelCmd) {
    $env:Path += ";" + (Split-Path $vercelCmd.FullName)
    Log "Added to PATH: $(Split-Path $vercelCmd.FullName)" DarkGray
  }
}
$vercelVersion = ""
try {
  $vercelVersion = (& vercel --version) 2>$null
  Log "Vercel CLI: $vercelVersion" DarkGray
} catch {
  Log "ERROR: Vercel CLI not found. Install with: npm i -g vercel" Red
  exit 2
}

# ---------- Confirm .vercel link (team + project) ----------
$projectFile = Join-Path $PWD ".vercel\project.json"
if (-not (Test-Path $projectFile)) {
  Log "ERROR: .vercel/project.json not found. Link first: vercel link --project truvern --scope nelson-ai-projects" Red
  exit 3
}
try {
  $proj = Get-Content $projectFile -Raw | ConvertFrom-Json
  Log "Linked project: $($proj.project.projectId) (team: nelson-ai-projects) " DarkGray
} catch {
  Log "WARNING: Could not read .vercel/project.json, continuing..." Yellow
}

# ---------- Get latest production deployment URL ----------
# Strategy:
#   1) Try reading last deploy log for "Production URL:"
#   2) Fallback: parse `vercel ls truvern --scope nelson-ai-projects` for a truvern-*.vercel.app URL
function Get-LatestDeploymentUrl {
  param([string]$project="truvern", [string]$scope="nelson-ai-projects")

  # 1) search recent logs
  $lastDeployLog = Get-ChildItem $logDir -Filter "phase12*deploy*.txt" -ErrorAction SilentlyContinue |
                   Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($lastDeployLog) {
    $line = Select-String -Path $lastDeployLog.FullName -Pattern 'Production URL:\s*(https?://\S+)' -SimpleMatch:$false | Select-Object -First 1
    if ($line) {
      $m = [regex]::Match($line.ToString(), 'https?://[^\s]+')
      if ($m.Success) { return $m.Value }
    }
  }

  # 2) parse vercel ls
  $ls = (& vercel ls $project --scope $scope) 2>&1
  $match = ($ls -split "`n") | Where-Object { $_ -match 'https?://truvern-[a-zA-Z0-9-]+\.vercel\.app' } | Select-Object -First 1
  if ($match) {
    $m = [regex]::Match($match, 'https?://truvern-[a-zA-Z0-9-]+\.vercel\.app')
    if ($m.Success) { return $m.Value }
  }

  return $null
}

$deployUrl = Get-LatestDeploymentUrl
if (-not $deployUrl) {
  Log "No deployment URL found. Creating a fresh production deploy..." Yellow
  # Build + deploy quickly; relies on project scripts already working
  & vercel deploy --prod --scope nelson-ai-projects | Tee-Object -FilePath $mainLog -Append | Out-Host
  $deployUrl = Get-LatestDeploymentUrl
}

if (-not $deployUrl) {
  Log "ERROR: Could not determine a production deployment URL." Red
  exit 4
}

Log "Using deployment: $deployUrl" Green | Tee-Object -FilePath $mainLog -Append | Out-Host

# ---------- Apply aliases ----------
$domains = @('truvern.com','www.truvern.com')
foreach ($d in $domains) {
  Log "Aliasing $deployUrl -> $d ..." Cyan
  # Vercel v48+: `vercel alias set <src> <target>`
  $aliasOut = (& vercel alias set $deployUrl $d --scope nelson-ai-projects) 2>&1
  $aliasOut | Tee-Object -FilePath $mainLog -Append | Out-Host

  if ($aliasOut -join "`n" -match 'Error|ERR' -and $aliasOut -join "`n" -notmatch 'already (point|assigned)') {
    Log "Alias warning for $d (see log). Continuing..." Yellow
  } else {
    Log "Alias OK for $d" Green
  }
}

# ---------- Verify public routes ----------
$base = "https://truvern.com"
$routes = @('/', '/pricing', '/login', '/subscribe', '/api/health', '/favicon.ico', '/manifest.json')
Log "Verifying public routes at $base ..." Cyan
"Base: $base" | Out-File -FilePath $vrfyLog -Encoding utf8

$all200 = $true
foreach ($r in $routes) {
  try {
    $u = "$base$r"
    $t0 = Get-Date
    $res = Invoke-WebRequest -UseBasicParsing -Method GET -Uri $u -TimeoutSec 20
    $ms = [int]((Get-Date) - $t0).TotalMilliseconds
    if ($res.StatusCode -eq 200) {
      $line = "OK $u -> 200 ($ms ms)"
      Log $line Green
      $line | Out-File -Append -FilePath $vrfyLog
    } else {
      $line = "ERR $u -> $($res.StatusCode)"
      Log $line Yellow
      $line | Out-File -Append -FilePath $vrfyLog
      $all200 = $false
    }
  } catch {
    $msg = "ERR $base$r -> $($_.Exception.Message)"
    Log $msg Red
    $msg | Out-File -Append -FilePath $vrfyLog
    $all200 = $false
  }
}

if ($all200) {
  Log "All public routes returned HTTP 200." Green
} else {
  Log "Some public routes failed. See $vrfyLog" Yellow
}

Log "Main log: $mainLog" DarkGray
Log "Verify log: $vrfyLog" DarkGray
Log "=== Phase125 complete ===" Cyan

# Friendly pause when launched via double-click
if ($Host.Name -match 'ConsoleHost') {
  Write-Host ""
  Read-Host "Press Enter to close"
}
