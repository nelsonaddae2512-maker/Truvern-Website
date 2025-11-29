# ============================
# Phase22-Rev5-StallBuster-Fixed.ps1
# Build with timeout, auto-fallback to server deploy, quick health check
# ============================

$ErrorActionPreference = 'Stop'
$host.ui.RawUI.WindowTitle = "Truvern • StallBuster"

# --- Always run from project root (safe in all launch modes) ---
if ($MyInvocation.MyCommand.Path) {
  $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
} else {
  $scriptDir = "C:\Users\MR.NELSON\Downloads\truvern"
}
Set-Location -Path $scriptDir
Write-Host "Running from project root: $scriptDir" -ForegroundColor DarkGray

# --- Config ---
$logsRoot          = Join-Path $scriptDir 'logs\phase22rev5'
$null = New-Item -ItemType Directory -Force -Path $logsRoot
$buildLog          = Join-Path $logsRoot ("build-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))
$deployLog         = Join-Path $logsRoot ("deploy-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))
$timeoutBuildSec   = 900   # 15 min
$timeoutDeploySec  = 420   # 7  min
$vercelCmd         = Join-Path $env:APPDATA 'npm\vercel.cmd'

function Kill-Stuck {
  Get-Process vercel,node -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}

function Ensure-Vercel {
  if (-not (Test-Path $vercelCmd)) {
    Write-Host "Installing vercel CLI..." -ForegroundColor Yellow
    npm i -g vercel@latest | Out-Null
  }
}

function Ensure-Auth {
  # If not logged in, open one-time device login
  & $vercelCmd whoami *> $null
  if ($LASTEXITCODE -ne 0) {
    Write-Host "Opening Vercel login (one-time)..." -ForegroundColor Yellow
    & $vercelCmd login
    & $vercelCmd whoami
    if ($LASTEXITCODE -ne 0) { throw "Vercel authentication failed." }
  }
}

function Run-Native {
  param(
    [Parameter(Mandatory)][string]$CmdLine,
    [Parameter(Mandatory)][string]$LogPath,
    [int]$TimeoutSec = 600
  )

  $quoted = $CmdLine + ' ' + ('> "{0}" 2>&1' -f $LogPath)
  $p = Start-Process -FilePath 'cmd.exe' -ArgumentList @('/c', $quoted) -PassThru -NoNewWindow
  if (-not $p.WaitForExit($TimeoutSec * 1000)) {
    try { Stop-Process -Id $p.Id -Force } catch {}
    throw "Timeout after ${TimeoutSec}s running: $CmdLine (see $LogPath)"
  }
  return $p.ExitCode
}

Start-Transcript -Path (Join-Path $logsRoot ("transcript-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))) -Force | Out-Null

try {
  Write-Host "[0] Clean up & ensure CLI..." -ForegroundColor Cyan
  Kill-Stuck
  Ensure-Vercel
  Ensure-Auth

  Write-Host "[1] Cleaning .next to force fresh compile..." -ForegroundColor DarkGray
  Remove-Item -Recurse -Force ".next" -ErrorAction SilentlyContinue

  Write-Host "[2] Building locally with timeout ($timeoutBuildSec s)..." -ForegroundColor Cyan
  $buildExit = Run-Native -CmdLine "`"$vercelCmd`" build --prod" -LogPath $buildLog -TimeoutSec $timeoutBuildSec

  if ($buildExit -eq 0) {
    Write-Host "  √ Local build finished -> $buildLog" -ForegroundColor Green
    Write-Host "[3] Deploying prebuilt bundle (timeout $timeoutDeploySec s)..." -ForegroundColor Cyan
    $deployExit = Run-Native -CmdLine "`"$vercelCmd`" deploy --prebuilt --prod --yes" -LogPath $deployLog -TimeoutSec $timeoutDeploySec
    if ($deployExit -ne 0) {
      Write-Host "  ? Prebuilt not found/refused – retrying as server-side deploy..." -ForegroundColor Yellow
      $deployExit = Run-Native -CmdLine "`"$vercelCmd`" --prod --yes" -LogPath $deployLog -TimeoutSec $timeoutDeploySec
      if ($deployExit -ne 0) { throw "Server-side deploy failed. See $deployLog" }
    }
  } else {
    Write-Host "  ? Local build failed/stalled – doing server-side deploy..." -ForegroundColor Yellow
    $deployExit = Run-Native -CmdLine "`"$vercelCmd`" --prod --yes" -LogPath $deployLog -TimeoutSec $timeoutDeploySec
    if ($deployExit -ne 0) { throw "Server-side deploy failed. See $deployLog" }
  }

  Write-Host "[4] Quick health check..." -ForegroundColor Cyan
  try {
    $h1 = Invoke-WebRequest -Uri "https://truvern.com/ops/health" -UseBasicParsing -TimeoutSec 20
    $h2 = Invoke-WebRequest -Uri "https://truvern.com/api/health" -UseBasicParsing -TimeoutSec 20
    Write-Host ("  Health OK -> /ops/health {0}, /api/health {1}" -f $h1.StatusCode,$h2.StatusCode) -ForegroundColor Green
  } catch { Write-Host ("  Health check skipped: {0}" -f $_.Exception.Message) -ForegroundColor DarkYellow }

  Write-Host "`nPhase22-Rev5-StallBuster complete." -ForegroundColor Green
  Write-Host "  Build log : $buildLog"  -ForegroundColor DarkGray
  Write-Host "  Deploy log: $deployLog" -ForegroundColor DarkGray
}
catch {
  Write-Host ("! " + $_.Exception.Message) -ForegroundColor Red
  Write-Host "  Build log : $buildLog"  -ForegroundColor DarkGray
  Write-Host "  Deploy log: $deployLog" -ForegroundColor DarkGray
}
finally {
  Stop-Transcript | Out-Null
  Kill-Stuck
}
