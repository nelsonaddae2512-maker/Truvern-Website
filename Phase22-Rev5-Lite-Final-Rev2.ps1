# Phase22-Rev5-Lite-Final-Rev2.ps1 — uses Start-Process (no cmd.exe), robust logging

$ErrorActionPreference = 'Continue'
$host.ui.RawUI.WindowTitle = "Truvern • StallBuster Lite (Rev2)"

$root = "C:\Users\MR.NELSON\Downloads\truvern"
Set-Location $root

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
  try { & $vercel --version | Out-Null }
  catch {
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

function Run-Vercel {
  param(
    [string[]]$Args,
    [string]$LogPath,
    [int]$TimeoutSec = 600
  )
  # run vercel without cmd.exe and capture both stdout/stderr
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = $vercel
  $psi.Arguments = ($Args -join ' ')
  $psi.UseShellExecute = $false
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError  = $true
  $p = New-Object System.Diagnostics.Process
  $p.StartInfo = $psi
  [void]$p.Start()
  $out = $p.StandardOutput.ReadToEnd()
  $err = $p.StandardError.ReadToEnd()

  if (-not $p.WaitForExit($TimeoutSec * 1000)) {
    try { $p.Kill() } catch {}
    $out += "`n*** Timeout after $TimeoutSec s ***"
  }
  $out + $err | Out-File -FilePath $LogPath -Encoding utf8
  return $p.ExitCode
}

Start-Transcript -Path $transcript -Force | Out-Null
try {
  Write-Host "[0] Cleaning stuck processes & ensuring CLI..." -ForegroundColor Cyan
  Kill-Stuck
  Ensure-Vercel
  Ensure-Auth

  Write-Host "[1] Deploying server-side (vercel --prod --yes)..." -ForegroundColor Cyan
  $exit = Run-Vercel @('--prod','--yes') $deployLog 600
  if ($exit -ne 0) { throw "Deploy failed with code $exit. See $deployLog" }

  Write-Host "[2] Health checks..." -ForegroundColor Cyan
  try {
    $h1 = Invoke-WebRequest -Uri "https://truvern.com/ops/health" -UseBasicParsing -TimeoutSec 20
    $h2 = Invoke-WebRequest -Uri "https://truvern.com/api/health" -UseBasicParsing -TimeoutSec 20
    Write-Host ("   OK -> /ops {0}, /api {1}" -f $h1.StatusCode,$h2.StatusCode) -ForegroundColor Green
  } catch { Write-Host ("   Skipped: {0}" -f $_.Exception.Message) -ForegroundColor DarkYellow }

  Write-Host "`n✅ Phase22-Rev5-Lite-Final-Rev2 complete." -ForegroundColor Green
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
