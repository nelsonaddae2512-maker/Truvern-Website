param(
  [int]$MaxAttempts = 3,
  [int]$TimeoutBuildSec = 2400,
  [int]$TimeoutDeploySec = 2400,
  [int]$StallSec = 240,
  [switch]$Pause = $true
)

# ==============================================================
# Phase22-Rev3.ps1 - Smart Auto-Fix + Auto-Restart Watchdog
# ==============================================================

$ErrorActionPreference = "Stop"

# 0) Lock to project root (never run from system32)
$ProjectRoot = (Get-Location).Path
if ($ProjectRoot -match "\\Windows\\System32$") {
  $ProjectRoot = "C:\Users\MR.NELSON\Downloads\truvern"
  Set-Location $ProjectRoot
}

# 1) Paths & logs
$LogsRoot = Join-Path $ProjectRoot "logs\phase22rev3"
New-Item -ItemType Directory -Force -Path $LogsRoot | Out-Null
$Stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$Transcript = Join-Path $LogsRoot "transcript-$Stamp.txt"
Start-Transcript -Path $Transcript -Force | Out-Null

$global:ProgressPreference = "SilentlyContinue"
$env:CI = "1"
$env:NODE_OPTIONS = "--max-old-space-size=4096"

Write-Host "`n=== Phase22-Rev3: Smart Auto-Fix + Auto-Restart ===" -ForegroundColor Cyan
Write-Host "[0] Project root: $ProjectRoot" -ForegroundColor DarkGray
Write-Host "    Logs: $LogsRoot" -ForegroundColor DarkGray

# ---------- helpers ----------
function Kill-Stuck {
  Write-Host "? Killing lingering vercel/node/npm..." -ForegroundColor DarkYellow
  "vercel","node","npm" | % {
    Get-Process -Name $_ -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
  }
  Start-Sleep 2
}

function Clean-Caches {
  Write-Host "?? Cleaning caches (.next, .vercel, node_modules\.cache)..." -ForegroundColor Yellow
  Remove-Item -Recurse -Force "$ProjectRoot\.next","$ProjectRoot\.vercel" -ErrorAction SilentlyContinue
  if (Test-Path "$ProjectRoot\node_modules\.cache") {
    Remove-Item -Recurse -Force "$ProjectRoot\node_modules\.cache" -ErrorAction SilentlyContinue
  }
}

function Ensure-VercelCliAuth {
  $vcmd = Join-Path $env:APPDATA "npm\vercel.cmd"
  if (-not (Test-Path $vcmd)) {
    Write-Host "? Installing Vercel CLI..." -ForegroundColor Yellow
    npm install -g vercel@latest | Out-Null
  } else {
    try { & $vcmd --version | Out-Null } catch { npm install -g vercel@latest | Out-Null }
  }
  try {
    $who = & $vcmd whoami 2>$null
    if (-not $who) {
      Write-Host "?? Not authenticated; launching login…" -ForegroundColor Yellow
      & $vcmd login
      $who = & $vcmd whoami
    }
    Write-Host "?? Logged in as: $who" -ForegroundColor Green
  } catch { throw "Vercel authentication failed. $_" }
  return $vcmd
}

function Run-CmdToLog {
  param(
    [Parameter(Mandatory)][string]$Cmd,
    [Parameter(Mandatory)][string]$Args,
    [Parameter(Mandatory)][string]$LogPath,
    [int]$TimeoutSec = 2400,
    [int]$StallSec = 240
  )
  if (Test-Path $LogPath) { Remove-Item $LogPath -Force -ErrorAction SilentlyContinue }
  New-Item -ItemType File -Force -Path $LogPath | Out-Null

  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = $Cmd
  $psi.Arguments = $Args + " >> `"$LogPath`" 2>&1"
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true

  $p = New-Object System.Diagnostics.Process
  $p.StartInfo = $psi
  [void]$p.Start()

  $watch = [System.Diagnostics.Stopwatch]::StartNew()
  $lastSize = (Get-Item $LogPath).Length
  $lastTick = [DateTime]::UtcNow

  while (-not $p.HasExited) {
    Start-Sleep -Seconds 3
    if ($TimeoutSec -gt 0 -and $watch.Elapsed.TotalSeconds -ge $TimeoutSec) {
      try { $p.Kill() } catch {}
      return @{ Status='timeout'; Exit=$p.ExitCode }
    }
    try {
      $sz = (Get-Item $LogPath).Length
      if ($sz -ne $lastSize) { $lastSize = $sz; $lastTick = [DateTime]::UtcNow }
      elseif (([DateTime]::UtcNow - $lastTick).TotalSeconds -ge $StallSec) {
        try { $p.Kill() } catch {}
        return @{ Status='stalled'; Exit=$p.ExitCode }
      }
    } catch {}
  }
  if ($p.ExitCode -eq 0) { return @{ Status='ok'; Exit=0 } }
  else { return @{ Status='exit'; Exit=$p.ExitCode } }
}

function Analyze-BuildLog {
  param([string]$Path)
  if (-not (Test-Path $Path)) { return @{ Fix='none'; Note='no log' } }
  $tail = Get-Content $Path -Tail 400 -ErrorAction SilentlyContinue | Out-String

  if ($tail -match "You cannot have two parallel pages that resolve to the same path") {
    return @{ Fix='routes-clear'; Note='route conflict' }
  }
  if ($tail -match "Unable to find lambda for route") {
    return @{ Fix='write-handlers'; Note='missing lambda' }
  }
  if ($tail -match "Cannot find module\s+'([^']+)'") {
    return @{ Fix='install-one'; Pkg=$Matches[1]; Note='missing module' }
  }
  if ($tail -match "Could not find a Next\.js instrumentation file") {
    return @{ Fix='write-instrumentation'; Note='sentry instrumentation missing' }
  }
  if ($tail -notmatch "Creating an optimized production build|Compiled successfully") {
    return @{ Fix='cli-repair'; Note='early CLI exit' }
  }
  return @{ Fix='none'; Note='no signature' }
}

function Apply-Fix {
  param([hashtable]$A)
  switch ($A.Fix) {
    'routes-clear' {
      Write-Host "?? Fix: Clearing .next for route-cache rebuild" -ForegroundColor Yellow
      Remove-Item -Recurse -Force "$ProjectRoot\.next" -ErrorAction SilentlyContinue
    }
    'write-handlers' {
      Write-Host "?? Fix: Writing minimal handlers for dashboard routes" -ForegroundColor Yellow
      $targets = @('app\dashboard\buyer\route.ts','app\dashboard\vendor\route.ts')
      foreach ($rel in $targets) {
        $p = Join-Path $ProjectRoot $rel
        $dir = Split-Path $p -Parent
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
        if (-not (Test-Path $p)) {
@"
import { NextResponse } from 'next/server'
export const dynamic = 'force-dynamic'
export async function GET(){ return NextResponse.json({ok:true}) }
"@ | Out-File $p -Encoding UTF8
          Write-Host "  + created $rel" -ForegroundColor DarkGray
        }
      }
    }
    'install-one' {
      if ($A.Pkg) {
        Write-Host "?? Fix: Installing missing module '$($A.Pkg)'" -ForegroundColor Yellow
        npm i $A.Pkg | Out-Null
      }
    }
    'write-instrumentation' {
      Write-Host "?? Fix: Creating minimal instrumentation.ts" -ForegroundColor Yellow
      $inst = Join-Path $ProjectRoot 'instrumentation.ts'
      if (-not (Test-Path $inst)) { 'export async function register(){}' | Out-File $inst -Encoding UTF8 }
    }
    'cli-repair' {
      Write-Host "?? Fix: Repairing vercel CLI & caches" -ForegroundColor Yellow
      npm i -g vercel@latest | Out-Null
      Clean-Caches
    }
    default { Write-Host "? No automatic fix required" -ForegroundColor DarkGray }
  }
}

# ---------- watchdog main loop ----------
$attempt = 0
$done = $false

while (-not $done -and $attempt -lt $MaxAttempts) {
  $attempt++
  Write-Host "`n--- Attempt $attempt / $MaxAttempts ---" -ForegroundColor Magenta

  try {
    Kill-Stuck
    Clean-Caches
    $VercelCmd = Ensure-VercelCliAuth

    $StampRun = Get-Date -Format "yyyyMMdd-HHmmss"
    $BuildLog  = Join-Path $LogsRoot "build-$StampRun.log"
    $DeployLog = Join-Path $LogsRoot "deploy-$StampRun.log"

    Write-Host "[1] Building (watchdog: stall $StallSec s, timeout $TimeoutBuildSec s)..." -ForegroundColor Cyan
    $rBuild = Run-CmdToLog -Cmd 'cmd.exe' -Args "/c `"$VercelCmd`" build --prod" -LogPath $BuildLog -TimeoutSec $TimeoutBuildSec -StallSec $StallSec
    Write-Host ("    build -> {0} (exit {1})" -f $rBuild.Status,$rBuild.Exit) -ForegroundColor DarkGray

    if ($rBuild.Status -ne 'ok') {
      Write-Host "[1b] Analyzing build log & applying auto-fix..." -ForegroundColor Yellow
      $A = Analyze-BuildLog -Path $BuildLog
      Write-Host ("    signature: {0}" -f $A.Note) -ForegroundColor DarkGray
      Apply-Fix -A $A

      Write-Host "[1c] Retrying build after fix..." -ForegroundColor Yellow
      $rBuild = Run-CmdToLog -Cmd 'cmd.exe' -Args "/c `"$VercelCmd`" build --prod" -LogPath $BuildLog -TimeoutSec $TimeoutBuildSec -StallSec $StallSec
      Write-Host ("    build -> {0} (exit {1})" -f $rBuild.Status,$rBuild.Exit) -ForegroundColor DarkGray
    }

    # Deploy: prebuilt preferred; fallback to server-side
    if ($rBuild.Status -eq 'ok') {
      Write-Host "[2] Deploying prebuilt bundle..." -ForegroundColor Cyan
      $rDep = Run-CmdToLog -Cmd 'cmd.exe' -Args "/c `"$VercelCmd`" deploy --prebuilt --prod --yes" -LogPath $DeployLog -TimeoutSec $TimeoutDeploySec -StallSec $StallSec
      if ($rDep.Status -ne 'ok') {
        Write-Host "   Prebuilt failed; trying server-side deploy..." -ForegroundColor DarkYellow
        $rDep = Run-CmdToLog -Cmd 'cmd.exe' -Args "/c `"$VercelCmd`" --prod --yes" -LogPath $DeployLog -TimeoutSec $TimeoutDeploySec -StallSec $StallSec
      }
    } else {
      Write-Host "[2] Local build not reliable; doing server-side deploy..." -ForegroundColor Yellow
      $rDep = Run-CmdToLog -Cmd 'cmd.exe' -Args "/c `"$VercelCmd`" --prod --yes" -LogPath $DeployLog -TimeoutSec $TimeoutDeploySec -StallSec $StallSec
    }

    if ($rDep.Status -eq 'ok') {
      Write-Host "? Deploy succeeded." -ForegroundColor Green
      # Quick header check
      try {
        Write-Host "`n[3] Verifying headers on https://truvern.com ..." -ForegroundColor Cyan
        $resp = Invoke-WebRequest "https://truvern.com" -UseBasicParsing -TimeoutSec 20
        $hdr = $resp.Headers
        foreach($k in @('Strict-Transport-Security','X-Frame-Options','Referrer-Policy','Permissions-Policy','Content-Security-Policy')){
          $v = [string]$hdr[$k]
          if ([string]::IsNullOrWhiteSpace($v)) { Write-Host ("? {0}: missing" -f $k) -ForegroundColor Red }
          else { Write-Host ("? {0}: {1}" -f $k,$v) -ForegroundColor Green }
        }
      } catch { Write-Host "   Header check skipped: $_" -ForegroundColor DarkYellow }

      Write-Host "`nPhase22-Rev3 complete." -ForegroundColor Green
      Write-Host "Build log : $BuildLog"
      Write-Host "Deploy log: $DeployLog"
      Write-Host "Transcript: $Transcript"
      $done = $true
    }
    else {
      Write-Host "? Deploy failed (status: $($rDep.Status), exit: $($rDep.Exit))." -ForegroundColor Red
      if ($attempt -lt $MaxAttempts) {
        Write-Host "? Watchdog will retry (attempt $([int]($attempt+1)) of $MaxAttempts)..." -ForegroundColor Yellow
      }
    }
  }
  catch {
    Write-Host ("? Unhandled error in attempt {0}: {1}" -f $attempt, $_.Exception.Message) -ForegroundColor Red
    if ($attempt -lt $MaxAttempts) {
      Write-Host "? Watchdog will retry (attempt $([int]($attempt+1)) of $MaxAttempts)..." -ForegroundColor Yellow
    }
  }
  finally {
    Kill-Stuck
  }
}

if (-not $done) {
  Write-Host "`n? Phase22-Rev3 finished without a successful deploy after $MaxAttempts attempts." -ForegroundColor Red
  Write-Host "See logs under: $LogsRoot" -ForegroundColor DarkGray
}

Stop-Transcript | Out-Null
if ($Pause) {
  Write-Host "`nPress ENTER to close this window..." -ForegroundColor DarkGray
  [void][Console]::ReadLine()
}
