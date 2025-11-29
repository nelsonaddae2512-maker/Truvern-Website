# Phase22-Rev5-Lite-Final-Rev3.ps1 — fixes pipeline stop, keeps full deploy logging

$ErrorActionPreference = 'Continue'
$host.ui.RawUI.WindowTitle = "Truvern • StallBuster Lite (Rev3)"

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
  try { & $vercel --version | Out-Host }
  catch {
    Write-Host "Installing vercel CLI..." -ForegroundColor Yellow
    npm i -g vercel@latest | Out-Null
  }
}

function Ensure-Auth {
  Write-Host "[Auth] Checking login..." -ForegroundColor Cyan
  $whoamiOut = & $vercel whoami 2>&1
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($whoamiOut)) {
    Write-Host "Opening Vercel login (one-time)..." -ForegroundColor Yellow
    & $vercel login
    $whoamiOut = & $vercel whoami 2>&1
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($whoamiOut)) {
      throw "Vercel authentication failed."
    }
  }
  Write-Host ("Authenticated as: {0}" -f $whoamiOut.Trim()) -ForegroundColor Green
}

function Run-Vercel {
  param(
    [string[]]$Args,
    [string]$LogPath,
    [int]$TimeoutSec = 600
  )
  Write-Host ("→ vercel {0}" -f ($Args -join ' ')) -ForegroundColor DarkGray
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = $vercel
  $psi.Arguments = ($Args -join ' ')
  $psi.UseShellExecute = $false
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
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

  Write-Host "`n✅ Phase22-Rev5-Lite-Final-Rev3 complete." -ForegroundColor Green
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
