# Phase123c-FixBuild2.ps1
# Robust build runner that ignores harmless stderr, checks real exit codes, and logs everything.

$ErrorActionPreference = 'Stop'

# ---------- Setup & logging ----------
$proj   = (Get-Location).Path
if ($proj -match '\\Windows\\System32($|\\)') {
  Write-Host "❌ Do not run from System32. cd into your project folder and rerun." -ForegroundColor Red
  exit 1
}

$ts       = Get-Date -Format "yyyyMMdd-HHmmss"
$logDir   = Join-Path $proj "logs"
$new = New-Item -ItemType Directory -Force -Path $logDir -ErrorAction SilentlyContinue

$mainLog  = Join-Path $logDir "phase123c-main-$ts.log"
$buildLog = Join-Path $logDir "phase123c-build-$ts.txt"

function Log([string]$msg, [string]$color='Cyan') {
  $line = "[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $msg
  $line | Tee-Object -FilePath $mainLog -Append | Out-Host
}

# ---------- Resolve CLI shims (prefer .cmd) ----------
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

$pnpmCmd   = Resolve-Cli 'pnpm'
$vercelCmd = Resolve-Cli 'vercel'  # kept if you want deploy later

Log "=== Phase123c: CLI Resolution ==="
Log "pnpm   = $pnpmCmd"
Log "vercel = $vercelCmd"

# ---------- Helpers to run native tools safely ----------
function Invoke-Native {
  param(
    [Parameter(Mandatory)] [string] $FilePath,
    [Parameter(Mandatory)] [string[]] $ArgumentList,
    [Parameter(Mandatory)] [string] $OutLog,
    [string] $ErrLog = $null,
    [string] $WorkDir = $proj
  )

  # Separate temp logs to avoid Start-Process restriction
  $tmpOut = [System.IO.Path]::ChangeExtension($OutLog, ".out.tmp")
  $tmpErr = if ($ErrLog) { [System.IO.Path]::ChangeExtension($ErrLog, ".err.tmp") } else { [System.IO.Path]::ChangeExtension($OutLog, ".err.tmp") }

  # Ensure files exist
  New-Item -ItemType File -Force -Path $tmpOut | Out-Null
  New-Item -ItemType File -Force -Path $tmpErr | Out-Null
  New-Item -ItemType File -Force -Path $OutLog | Out-Null
  if ($ErrLog) { New-Item -ItemType File -Force -Path $ErrLog | Out-Null }

  $p = Start-Process -FilePath $FilePath `
                    -ArgumentList $ArgumentList `
                    -RedirectStandardOutput $tmpOut `
                    -RedirectStandardError  $tmpErr `
                    -NoNewWindow -Wait -PassThru -WorkingDirectory $WorkDir

  # Merge logs
  Get-Content $tmpOut | Add-Content $OutLog
  Get-Content $tmpErr | Add-Content $OutLog
  if ($ErrLog) {
    Get-Content $tmpOut | Add-Content $ErrLog
    Get-Content $tmpErr | Add-Content $ErrLog
  }
  Remove-Item $tmpOut,$tmpErr -ErrorAction SilentlyContinue

  return $p.ExitCode
}

# ---------- package.json sanity ----------
$pkgPath = Join-Path $proj "package.json"
if (-not (Test-Path $pkgPath)) { Log "❌ package.json missing." 'Red'; exit 2 }
$pkg = Get-Content $pkgPath -Raw | ConvertFrom-Json
if (-not $pkg.scripts.build) {
  Log "⚠️  No 'build' script found; adding 'next build'." 'Yellow'
  $pkg.scripts.build = "next build"
  ($pkg | ConvertTo-Json -Depth 100) | Set-Content $pkgPath -Encoding UTF8
}

# ---------- install ----------
Log "⏳ pnpm install --frozen-lockfile ..."
$code = Invoke-Native -FilePath $pnpmCmd -ArgumentList @('install','--frozen-lockfile') -OutLog $mainLog
if ($code -ne 0) { Log "❌ pnpm install failed (exit $code)." 'Red'; exit 3 }

# ---------- prisma generate ----------
Log "⏳ prisma generate ..."
$code = Invoke-Native -FilePath $pnpmCmd -ArgumentList @('exec','prisma','generate') -OutLog $mainLog
if ($code -ne 0) { Log "❌ Prisma generation failed (exit $code)." 'Red'; exit 4 }
Log "✅ Prisma client generated."

# ---------- build ----------
Log "⏳ Building (logs -> $buildLog) ..."
$code = Invoke-Native -FilePath $pnpmCmd -ArgumentList @('run','build') -OutLog $buildLog
if ($code -ne 0) {
  Log "⚠️ Build failed (exit $code); retrying once..." 'Yellow'
  $code = Invoke-Native -FilePath $pnpmCmd -ArgumentList @('run','build') -OutLog $buildLog
}
if ($code -ne 0) {
  Log "❌ Build failed (exit $code)." 'Red'
  Log "Main:  $mainLog"
  Log "Build: $buildLog"
  exit 5
}

# Mirror build log into main log tail
"`n--- Build log tail ---`n" | Add-Content $mainLog
Get-Content $buildLog -Tail 80 | Add-Content $mainLog

Log "✅ Build succeeded." 'Green'
Log "=== Phase123c complete ===" 'Cyan'
Write-Host "`nMain log:  $mainLog"
Write-Host "Build log: $buildLog"
Write-Host "`nPress Enter to close..." -NoNewline
[void][Console]::ReadLine()
