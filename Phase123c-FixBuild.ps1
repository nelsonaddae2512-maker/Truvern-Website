# Phase123c-FixBuild.ps1 — prefer *.cmd shims; prisma+build with clean logging
$ErrorActionPreference = 'Stop'

# ----- paths & logs -----
$ts       = Get-Date -Format "yyyyMMdd-HHmmss"
$proj     = (Get-Location).Path
$logDir   = Join-Path $proj "logs"
$mainLog  = Join-Path $logDir "phase123c-main-$ts.log"
$buildLog = Join-Path $logDir "phase123c-build-$ts.txt"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

if ($proj -match '\\Windows\\System32($|\\)') {
  Write-Host "❌ Do not run from System32. cd into your project folder and rerun." -ForegroundColor Red
  exit 1
}

function Log([string]$msg, [string]$color='Cyan'){
  $line="[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"),$msg
  $line | Tee-Object -FilePath $mainLog -Append | Out-Host
}

# ----- prefer .cmd shim over .ps1 -----
function Resolve-Cli([string]$name){
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
$vercelCmd = Resolve-Cli 'vercel'  # kept for later if you want to deploy

Log "=== Phase123c: CLI Resolution ==="
Log "pnpm   = $pnpmCmd"
Log "vercel = $vercelCmd"

# ----- sanity: package.json / build script -----
$pkgPath = Join-Path $proj "package.json"
if (-not (Test-Path $pkgPath)) { Log "❌ package.json missing." 'Red'; exit 2 }
$pkg = Get-Content $pkgPath -Raw | ConvertFrom-Json
if (-not $pkg.scripts.build) {
  Log "⚠️  No 'build' script found; adding 'next build'." 'Yellow'
  $pkg.scripts.build = "next build"
  ($pkg | ConvertTo-Json -Depth 100) | Set-Content $pkgPath -Encoding UTF8
}

# ----- install -----
Log "⏳ pnpm install (frozen-lockfile)..."
& "$pnpmCmd" install --frozen-lockfile *>&1 | Tee-Object -FilePath $mainLog -Append | Out-Host
if ($LASTEXITCODE -ne 0) { Log "❌ pnpm install failed." 'Red'; exit 3 }

# ----- prisma generate (using .cmd directly; no cmd.exe redirection) -----
Log "⏳ Generating Prisma client..."
& "$pnpmCmd" exec prisma generate *>&1 | Tee-Object -FilePath $mainLog -Append | Out-Host
if ($LASTEXITCODE -ne 0) { Log "❌ Prisma generation failed." 'Red'; exit 4 }
Log "✅ Prisma client generated."

# ----- build (PowerShell merge streams -> Tee) -----
Log "⏳ Building (logs -> $buildLog)..."
New-Item -ItemType File -Path $buildLog -Force | Out-Null
& "$pnpmCmd" run build *>&1 |
  Tee-Object -FilePath $buildLog -Append |
  Tee-Object -FilePath $mainLog -Append |
  Out-Host
$code = $LASTEXITCODE

if ($code -ne 0) {
  Log "⚠️ Build failed; trying a second run..." 'Yellow'
  & "$pnpmCmd" run build *>&1 |
    Tee-Object -FilePath $buildLog -Append |
    Tee-Object -FilePath $mainLog -Append |
    Out-Host
  $code = $LASTEXITCODE
}

if ($code -ne 0) {
  Log "❌ Build failed." 'Red'
  Log "Main:  $mainLog"
  Log "Build: $buildLog"
  exit 5
}

Log "✅ Build succeeded." 'Green'
Log "=== Phase123c complete ===" 'Cyan'
Write-Host "`nMain log:  $mainLog"
Write-Host "Build log: $buildLog"
Write-Host "`nPress Enter to close..." -NoNewline
[void][Console]::ReadLine()
