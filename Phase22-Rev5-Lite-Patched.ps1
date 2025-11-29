# Phase22-Rev5-Lite-Patched.ps1 — guaranteed logging + server deploy

$ErrorActionPreference = 'Stop'
$host.ui.RawUI.WindowTitle = "Truvern • StallBuster Lite Patched"

# Always run from project root
$root = "C:\Users\MR.NELSON\Downloads\truvern"
Set-Location $root

# Paths & CLI setup
$vercel = Join-Path $env:APPDATA 'npm\vercel.cmd'
$logs   = Join-Path $root 'logs\phase22rev5-lite'
New-Item -Force -ItemType Directory -Path $logs | Out-Null
$stamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
$deployLog = Join-Path $logs "deploy-$stamp.log"
$transcript = Join-Path $logs "transcript-$stamp.log"

function Kill-Stuck {
  Get-Process vercel,node -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}

function Ensure-Vercel {
  if (-not (Test-Path $vercel)) {
    Write-Host "Installing vercel CLI..." -ForegroundColor Yellow
    npm i -g vercel@latest | Out-Null
  }
}

function Ensure-Auth {
  & $vercel whoami *> $null
  if ($LASTEXITCODE -ne 0) {
    Write-Host "Opening Vercel login (one-time)..." -ForegroundColor Yellow
    & $vercel login
    & $vercel whoami
    if ($LASTEXITCODE -ne 0) { throw "Vercel authentication failed." }
  }
}

function Run-Logged {
  param(
    [string]$cmdLine,
    [string]$logPath,
    [int]$timeoutSec = 600
  )
  Write-Host "→ $cmdLine" -ForegroundColor DarkGray
  $p = Start-Process -FilePath 'cmd.exe' -ArgumentList @('/c', "$cmdLine > `"$logPath`" 2>&1") -NoNewWindow -PassThru
  if (-not $p.WaitForExit($timeoutSec * 1000)) {
    try { Stop-Process -Id $p.Id -Force } catch {}
    throw "Timeout after $timeoutSec s (see $logPath)"
  }
  return $p.ExitCode
}

Start-Transcript -Path $transcript -Force | Out-Null
try {
  Write-Host "[0] Cleaning stuck processes & ensuring CLI..." -ForegroundColor Cyan
  Kill-Stuck
  Ensure-Vercel
  Ensure-Auth

  Write-Host "[1] Deploying server-side (vercel --prod --yes)..." -ForegroundColor Cyan
  $exit = Run-Logged "`"$vercel`" --prod --yes" $deployLog 600
  if ($exit -ne 0) { throw "Deploy failed with code $exit. See $deployLog" }

  Write-Host "[2] Health checks..." -ForegroundColor Cyan
  try {
    $h1 = Invoke-WebRequest -Uri "https://truvern.com/ops/health" -UseBasicParsing -TimeoutSec 20
    $h2 = Invoke-WebRequest -Uri "https://truvern.com/api/health" -UseBasicParsing -TimeoutSec 20
    Write-Host ("   OK -> /ops {0}, /api {1}" -f $h1.StatusCode,$h2.StatusCode) -ForegroundColor Green
  } catch { Write-Host ("   Skipped: {0}" -f $_.Exception.Message) -ForegroundColor DarkYellow }

  Write-Host "`n✅ Phase22-Rev5-Lite-Patched complete." -ForegroundColor Green
  Write-Host "  Deploy log: $deployLog" -ForegroundColor DarkGray
}
catch {
  Write-Host ("❌ " + $_.Exception.Message) -ForegroundColor Red
  Write-Host "  Deploy log: $deployLog" -ForegroundColor DarkGray
}
finally {
  Stop-Transcript | Out-Null
  Kill-Stuck
}
