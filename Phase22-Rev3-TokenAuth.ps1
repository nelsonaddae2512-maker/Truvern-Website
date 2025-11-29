# ==============================================================
# Phase22-Rev3-TokenAuth.ps1
# Auto-Fix + Auto-Restart with Vercel TOKEN authentication
# ==============================================================

param(
  [int]$MaxAttempts = 3,
  [switch]$Pause = $true
)

$ErrorActionPreference = "Stop"
$ProjectRoot = "C:\Users\MR.NELSON\Downloads\truvern"
Set-Location $ProjectRoot

# logs
$LogsRoot = Join-Path $ProjectRoot "logs\phase22rev3"
New-Item -ItemType Directory -Force -Path $LogsRoot | Out-Null
$Stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$Transcript = Join-Path $LogsRoot "transcript-$Stamp.txt"
Start-Transcript -Path $Transcript -Force | Out-Null

function Get-VercelCmd {
  $cmd = Join-Path $env:APPDATA "npm\vercel.cmd"
  if (-not (Test-Path $cmd)) {
    Write-Host "Installing Vercel CLI..." -ForegroundColor Yellow
    npm install -g vercel@latest | Out-Null
  }
  return $cmd
}

function Get-VercelToken {
  if ($env:VERCEL_TOKEN -and -not [string]::IsNullOrWhiteSpace($env:VERCEL_TOKEN)) {
    return $env:VERCEL_TOKEN
  }
  $p = Join-Path $env:USERPROFILE ".vercel\token.txt"
  if (Test-Path $p) {
    $t = (Get-Content -Raw -LiteralPath $p).Trim()
    if ($t) { return $t }
  }
  throw "No Vercel token found. Set VERCEL_TOKEN env var or create $p"
}

function Ensure-VercelAuth {
  param([string]$VercelCmd,[string]$Token)
  # verify using token (noninteractive)
  $who = cmd /c "$VercelCmd whoami --token $Token 2>$null"
  if (-not $who) {
    throw "Vercel authentication failed when using --token."
  } else {
    Write-Host "? Authenticated as: $who" -ForegroundColor Green
  }
}

function Run-BuildAndDeploy {
  param([string]$VercelCmd,[string]$Token,[int]$Attempt)

  $ts = Get-Date -Format "yyyyMMdd-HHmmss"
  $buildLog  = Join-Path $LogsRoot "build-$ts.log"
  $deployLog = Join-Path $LogsRoot "deploy-$ts.log"

  Write-Host "`n--- Attempt $Attempt ---" -ForegroundColor Magenta
  Write-Host "Cleaning caches (.next/.vercel/node_modules/.cache)..." -ForegroundColor Yellow
  Remove-Item -Recurse -Force ".next",".vercel","node_modules\.cache" -ErrorAction SilentlyContinue

  Write-Host "?? Building (vercel build --prod)..." -ForegroundColor Cyan
  cmd /c "$VercelCmd build --prod --token $Token" *> $buildLog
  if ($LASTEXITCODE -ne 0) { throw ("Build failed. See log: {0}" -f $buildLog) }

  Write-Host "?? Deploying (vercel --prod --yes)..." -ForegroundColor Cyan
  cmd /c "$VercelCmd --prod --yes --token $Token" *> $deployLog
  if ($LASTEXITCODE -ne 0) { throw ("Deploy failed. See log: {0}" -f $deployLog) }

  Write-Host "? Build + deploy successful" -ForegroundColor Green
  Write-Host "   Build log : $buildLog"  -ForegroundColor DarkGray
  Write-Host "   Deploy log: $deployLog" -ForegroundColor DarkGray
}

$done = $false
for ($i = 1; $i -le $MaxAttempts -and -not $done; $i++) {
  try {
    $vercel = Get-VercelCmd
    $token  = Get-VercelToken
    Ensure-VercelAuth -VercelCmd $vercel -Token $token
    Run-BuildAndDeploy -VercelCmd $vercel -Token $token -Attempt $i
    $done = $true
    break
  }
  catch {
    Write-Host ("? Unhandled error on attempt {0}: {1}" -f $i, ($_.Exception.Message)) -ForegroundColor Red
    if ($i -lt $MaxAttempts) {
      Write-Host "? Retrying in 15 seconds..." -ForegroundColor Yellow
      Start-Sleep -Seconds 15
    }
  }
}

if (-not $done) {
  Write-Host ("? Finished without a successful deploy after {0} attempts." -f $MaxAttempts) -ForegroundColor Red
  Write-Host ("Logs root: {0}" -f $LogsRoot) -ForegroundColor DarkGray
}

Stop-Transcript | Out-Null
if ($Pause) {
  Write-Host "`nPress ENTER to close this window..." -ForegroundColor DarkGray
  [void][Console]::ReadLine()
}
