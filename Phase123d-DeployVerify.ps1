# Phase123d-DeployVerify.ps1
# Deploy to Vercel prod and verify routes (safe logging + exit-code checks)

$ErrorActionPreference = 'Stop'
$proj = (Get-Location).Path
if ($proj -match '\\Windows\\System32($|\\)') {
  Write-Host "❌ Do not run from System32. cd into your project folder and rerun." -ForegroundColor Red
  exit 1
}

# ---------- logging ----------
$ts      = Get-Date -Format "yyyyMMdd-HHmmss"
$logDir  = Join-Path $proj "logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$mainLog = Join-Path $logDir "phase123d-main-$ts.log"
$depLog  = Join-Path $logDir "phase123d-deploy-$ts.txt"
$vrfLog  = Join-Path $logDir "route-verify-$ts.txt"

function Log([string]$m, [string]$color='Cyan') {
  $line = "[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $m
  $line | Tee-Object -FilePath $mainLog -Append | Out-Host
}

# ---------- resolve CLI ----------
function Resolve-Cli([string]$name) {
  try {
    $w = & where.exe "$name.cmd" 2>$null
    if ($LASTEXITCODE -eq 0 -and $w) { return ($w -split "`r?`n")[0].Trim() }
  } catch {}
  $cand = Get-ChildItem "$env:APPDATA\npm" -Filter "$name*.cmd" -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($cand) { return $cand.FullName }
  $gc = Get-Command $name -ErrorAction SilentlyContinue
  if ($gc) { return $gc.Source }
  throw "$name not found in PATH or %APPDATA%\npm"
}
$vercelCmd = Resolve-Cli 'vercel'

# ---------- native runner ----------
function Invoke-Native {
  param(
    [Parameter(Mandatory)] [string] $FilePath,
    [Parameter(Mandatory)] [string[]] $ArgumentList,
    [Parameter(Mandatory)] [string] $OutLog,
    [string] $ErrLog = $null,
    [string] $WorkDir = $proj
  )
  $tmpOut = [System.IO.Path]::ChangeExtension($OutLog, ".out.tmp")
  $tmpErr = if ($ErrLog) { [System.IO.Path]::ChangeExtension($ErrLog, ".err.tmp") } else { [System.IO.Path]::ChangeExtension($OutLog, ".err.tmp") }
  New-Item -ItemType File -Force -Path $tmpOut,$tmpErr,$OutLog | Out-Null
  if ($ErrLog) { New-Item -ItemType File -Force -Path $ErrLog | Out-Null }

  $p = Start-Process -FilePath $FilePath `
                     -ArgumentList $ArgumentList `
                     -RedirectStandardOutput $tmpOut `
                     -RedirectStandardError  $tmpErr `
                     -NoNewWindow -Wait -PassThru -WorkingDirectory $WorkDir

  Get-Content $tmpOut | Add-Content $OutLog
  Get-Content $tmpErr | Add-Content $OutLog
  if ($ErrLog) {
    Get-Content $tmpOut | Add-Content $ErrLog
    Get-Content $tmpErr | Add-Content $ErrLog
  }
  Remove-Item $tmpOut,$tmpErr -ErrorAction SilentlyContinue
  return $p.ExitCode
}

# ---------- deploy ----------
Log "=== Phase123d: Deploy & Verify ==="
Log "Deploying with: $vercelCmd"
$code = Invoke-Native -FilePath $vercelCmd -ArgumentList @('--prod','--yes') -OutLog $depLog
if ($code -ne 0) {
  Log "❌ Vercel deploy failed (exit $code). See $depLog" 'Red'; exit 2
}

# Try to extract the “Production:” URL from deploy output; fall back to main site
$prodUrl = (Select-String -Path $depLog -Pattern 'Production:\s*(https?://\S+)' -AllMatches).Matches |
  Select-Object -First 1 | ForEach-Object { $_.Groups[1].Value }
if (-not $prodUrl) { $prodUrl = "https://truvern.com" }

Log "Production URL: $prodUrl"

# ---------- verify routes ----------
$routes = @(
  '/', '/trust-network', '/vendors', '/reports/board', '/reports/board/preview',
  '/pricing', '/subscribe', '/security', '/login'
)

$okAll = $true
"Base: $prodUrl" | Out-File $vrfLog -Encoding utf8
foreach ($r in $routes) {
  try {
    $u  = "$prodUrl".TrimEnd('/') + $r
    $t0 = Get-Date
    $res = Invoke-WebRequest -UseBasicParsing -Method GET -Uri $u -TimeoutSec 20
    $ms = [int]((Get-Date) - $t0).TotalMilliseconds
    if ($res.StatusCode -eq 200) {
      $line = "OK  {0} -> 200 ({1} ms)" -f $u, $ms
      $line | Tee-Object -FilePath $vrfLog -Append | Out-Host
    } else {
      $okAll = $false
      $line = "ERR {0} -> {1}" -f $u, $res.StatusCode
      $line | Tee-Object -FilePath $vrfLog -Append | Out-Host
    }
  } catch {
    $okAll = $false
    $line = "ERR {0} -> {1}" -f ("$prodUrl".TrimEnd('/') + $r), $_.Exception.Message
    $line | Tee-Object -FilePath $vrfLog -Append | Out-Host
  }
}

if ($okAll) {
  Log "✅ All key routes returned HTTP 200." 'Green'
} else {
  Log "⚠️  Some routes failed. See $vrfLog" 'Yellow'
}

Log "Deploy log: $depLog"
Log "Verify log: $vrfLog"
Write-Host "`n=== Phase123d complete ===" -ForegroundColor Cyan
Write-Host "`nMain log:  $mainLog`nDeploy:    $depLog`nVerify:    $vrfLog"
Write-Host "`nPress Enter to close..." -NoNewline
[void][Console]::ReadLine()
