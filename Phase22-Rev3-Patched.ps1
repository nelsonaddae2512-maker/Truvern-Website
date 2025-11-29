# ==============================================================
# Phase22-Rev3-Patched.ps1
# Auto-Fix + Auto-Restart + Persistent Vercel Auth
# ==============================================================

param(
  [int]$MaxAttempts = 3,
  [switch]$Pause = $true
)

$ErrorActionPreference = "Stop"
$ProjectRoot = "C:\Users\MR.NELSON\Downloads\truvern"
Set-Location $ProjectRoot
$LogsRoot = Join-Path $ProjectRoot "logs\phase22rev3"
New-Item -ItemType Directory -Force -Path $LogsRoot | Out-Null
$Stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$Transcript = Join-Path $LogsRoot "transcript-$Stamp.txt"
Start-Transcript -Path $Transcript -Force | Out-Null

function Ensure-VercelCliAuth {
  $vercelCmd = Join-Path $env:APPDATA "npm\vercel.cmd"
  if (-not (Test-Path $vercelCmd)) {
    Write-Host "Installing Vercel CLI..." -ForegroundColor Yellow
    npm install -g vercel@latest | Out-Null
  }

  # Check login state
  $who = cmd /c "$vercelCmd whoami 2>$null"
  if (-not $who) {
    Write-Host "?? Attempting reauthentication..." -ForegroundColor Yellow

    $authPath = "$env:USERPROFILE\.vercel\auth.json"
    if (Test-Path $authPath) {
      Write-Host "Restoring cached Vercel session..." -ForegroundColor DarkGray
    } else {
      Write-Host "Opening Vercel login prompt (one-time)..." -ForegroundColor Yellow
      cmd /c "$vercelCmd login"
    }

    $who = cmd /c "$vercelCmd whoami 2>$null"
  }

  if (-not $who) {
    throw "Vercel authentication still failed. Run 'vercel login' manually once."
  } else {
    Write-Host "? Authenticated as: $who" -ForegroundColor Green
  }

  return $vercelCmd
}

# Core deploy logic
function Run-BuildAndDeploy {
  param([string]$VercelCmd, [int]$Attempt)
  $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $buildLog = "logs\phase22rev3\build-$timestamp.log"
  $deployLog = "logs\phase22rev3\deploy-$timestamp.log"

  Write-Host "`n--- Attempt $Attempt ---" -ForegroundColor Magenta
  Write-Host "Cleaning caches..." -ForegroundColor Yellow
  Remove-Item -Recurse -Force ".next", ".vercel", "node_modules\.cache" -ErrorAction SilentlyContinue

  Write-Host "?? Building..." -ForegroundColor Cyan
  cmd /c "$VercelCmd build --prod" *> $buildLog
  if ($LASTEXITCODE -ne 0) { throw "Build failed. Check $buildLog" }

  Write-Host "?? Deploying..." -ForegroundColor Cyan
  cmd /c "$VercelCmd --prod --yes" *> $deployLog
  if ($LASTEXITCODE -ne 0) { throw "Deploy failed. Check $deployLog" }

  Write-Host "? Build + deploy successful" -ForegroundColor Green
}

# Main watchdog loop
for ($i = 1; $i -le $MaxAttempts; $i++) {
  try {
    $vercelCmd = Ensure-VercelCliAuth
    Run-BuildAndDeploy -VercelCmd $vercelCmd -Attempt $i
    Write-Host "`nPhase22-Rev3-Patched complete ?" -ForegroundColor Green
    Write-Host "Transcript: $Transcript" -ForegroundColor DarkGray
    Stop-Transcript | Out-Null
    exit 0
  }
  catch {
    Write-Host ("âš  Unhandled error on attempt {0}: {1}" -f $i, ($_.Exception.Message)) -ForegroundColor Red
    if ($i -lt $MaxAttempts) {
      Write-Host "? Retrying in 15 seconds..." -ForegroundColor Yellow
      Start-Sleep -Seconds 15
    } else {
      Write-Host "? All $MaxAttempts attempts failed." -ForegroundColor Red
      Write-Host "Logs under: $LogsRoot" -ForegroundColor DarkGray
    }
  }
}

if ($Pause) {
  Write-Host "`nPress ENTER to close this window..." -ForegroundColor DarkGray
  [void][Console]::ReadLine()
}
