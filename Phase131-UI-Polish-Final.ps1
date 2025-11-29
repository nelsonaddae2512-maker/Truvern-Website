<# =======================================================================
 Phase131-UI-Polish-Final.ps1
 Purpose:
   - Polish public assets (favicon, manifest, robots, sitemap)
   - Install deps with PNPM and build all workspaces
   - Verify CSS outputs for Next.js apps
 Notes:
   - ASCII only. Uses script folder as repo root. Writes a transcript log.
 ======================================================================= #>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ----------------------- Resolve repo root -------------------------------
if (-not $PSScriptRoot -or [string]::IsNullOrWhiteSpace([string]$PSScriptRoot)) {
  $PSScriptRoot = (Get-Location).Path
}
$RepoRoot = (Resolve-Path -LiteralPath $PSScriptRoot).Path
Set-Location $RepoRoot

# Safety: avoid running from system32
$badRoots = @('C:\Windows\System32','C:\WINDOWS\system32')
if ($badRoots -contains (Get-Location).Path) {
  Write-Error "Refusing to run from system32. Run from C:\Users\MR.NELSON\Downloads\truvern"
  exit 1
}

# ----------------------- Transcript -------------------------------------
$LogPath = Join-Path $RepoRoot "Phase131-UI-Polish-Final.log"
if (Test-Path $LogPath) { Remove-Item $LogPath -Force -ErrorAction SilentlyContinue }
Start-Transcript -Path $LogPath | Out-Null

Write-Host "=== Phase131: UI Polish and Final Build ===" -ForegroundColor Cyan
Write-Host ("Repo Root: {0}" -f $RepoRoot) -ForegroundColor DarkCyan

# ----------------------- Helper funcs -----------------------------------
function Ensure-Dir {
  param([Parameter(Mandatory)][string]$Path)
  if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
}

function Write-Text {
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][string]$Content,
    [switch]$OnlyIfMissing
  )
  if ($OnlyIfMissing -and (Test-Path $Path)) { return }
  $folder = Split-Path $Path -Parent
  Ensure-Dir -Path $folder
  Set-Content -Path $Path -Value $Content -Encoding UTF8
}

function Ensure-Favicon {
  param([Parameter(Mandatory)][string]$PublicDir)
  $icoPath = Join-Path $PublicDir "favicon.ico"
  if (Test-Path $icoPath) { return }
  # Tiny 16x16 blue dot ICO (base64)
  $b64 = @"
AAABAAEAEBAAAAAAIABoAwAAFgAAACgAAAAQAAAAIAAAAAEACAAAAAAAAAEAAAAAAAAAAAAA
AAAAAAD///8A//////////8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP///wD///8A////AP//
/wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A
"@
  $bytes = [Convert]::FromBase64String(($b64 -replace '\s',''))
  [IO.File]::WriteAllBytes($icoPath, $bytes) | Out-Null
}

function Ensure-Manifest {
  param(
    [Parameter(Mandatory)][string]$PublicDir,
    [Parameter(Mandatory)][string]$AppName,
    [Parameter(Mandatory)][string]$ShortName
  )
  $manifestPath = Join-Path $PublicDir "site.webmanifest"
  if (Test-Path $manifestPath) { return }
  $json = @"
{
  "name": "$AppName",
  "short_name": "$ShortName",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#0b1221",
  "theme_color": "#0b1221",
  "icons": [
    { "src": "/favicon.ico", "sizes": "16x16 32x32 48x48", "type": "image/x-icon" }
  ]
}
"@
  Write-Text -Path $manifestPath -Content $json
}

function Ensure-Robots-Sitemap {
  param([Parameter(Mandatory)][string]$PublicDir, [Parameter(Mandatory)][string]$BaseUrl)
  $robotsPath  = Join-Path $PublicDir "robots.txt"
  $sitemapPath = Join-Path $PublicDir "sitemap.txt"
  if (-not (Test-Path $robotsPath)) {
    $robots = "User-agent: *`nAllow: /`nSitemap: $BaseUrl/sitemap.txt`n"
    Write-Text -Path $robotsPath -Content $robots
  }
  if (-not (Test-Path $sitemapPath)) {
    $smap = @"
$BaseUrl/
$BaseUrl/trust-network
$BaseUrl/vendors
$BaseUrl/board
"@
    Write-Text -Path $sitemapPath -Content $smap
  }
}

function Find-WorkspacePaths {
  # Returns an array of app paths that look like Next.js apps
  $candidates = @()
  $appsDir = Join-Path $RepoRoot "apps"
  if (Test-Path $appsDir) {
    Get-ChildItem $appsDir -Directory | ForEach-Object {
      $pkg = Join-Path $_.FullName "package.json"
      $nextCfg = Join-Path $_.FullName "next.config.js"
      $nextCfgTs = Join-Path $_.FullName "next.config.mjs"
      if (Test-Path $pkg -and ((Test-Path $nextCfg) -or (Test-Path $nextCfgTs))) {
        $candidates += $_.FullName
      }
    }
  }
  return $candidates
}

function Verify-CSS {
  param([Parameter(Mandatory)][string]$AppDir)
  $cssDir = Join-Path $AppDir ".next\static\css"
  if (-not (Test-Path $cssDir)) {
    return @{ app=$AppDir; ok=$false; reason=".next/static/css not found" }
  }
  $files = Get-ChildItem $cssDir -File -ErrorAction SilentlyContinue
  if (-not $files -or $files.Count -eq 0) {
    return @{ app=$AppDir; ok=$false; reason="no CSS files emitted" }
  }
  $total = ($files | Measure-Object -Property Length -Sum).Sum
  return @{ app=$AppDir; ok=($total -gt 0); reason=("bytes=" + $total) }
}

# ----------------------- Tooling checks ----------------------------------
Write-Host "Step 1/6: Checking Node and PNPM ..." -ForegroundColor Cyan
$nodeVersion = (& node --version) 2>$null
if (-not $nodeVersion) { throw "Node.js not found on PATH. Please install Node 18+." }
Write-Host ("Node: {0}" -f $nodeVersion.Trim()) -ForegroundColor Green

$pnpmVersion = (& pnpm --version) 2>$null
if (-not $pnpmVersion) {
  Write-Host "PNPM not found; installing globally with npm i -g pnpm ..." -ForegroundColor Yellow
  npm i -g pnpm | Out-Null
  $pnpmVersion = (& pnpm --version)
}
Write-Host ("PNPM: {0}" -f $pnpmVersion.Trim()) -ForegroundColor Green

# ----------------------- Asset polish ------------------------------------
Write-Host "Step 2/6: Polishing public assets (favicon, manifest, robots) ..." -ForegroundColor Cyan

$apps = Find-WorkspacePaths
if (-not $apps -or $apps.Count -eq 0) {
  Write-Host "No Next.js workspaces found under apps/. Continuing with repo root public/ if present." -ForegroundColor Yellow
  $fallbackPublic = Join-Path $RepoRoot "public"
  if (Test-Path $fallbackPublic) {
    Ensure-Favicon -PublicDir $fallbackPublic
    Ensure-Manifest -PublicDir $fallbackPublic -AppName "Truvern" -ShortName "Truvern"
    Ensure-Robots-Sitemap -PublicDir $fallbackPublic -BaseUrl "https://truvern.com"
  }
} else {
  foreach ($app in $apps) {
    $publicDir = Join-Path $app "public"
    Ensure-Dir -Path $publicDir
    Ensure-Favicon -PublicDir $publicDir

    $name = Split-Path $app -Leaf
    $appName = "Truvern - " + $name
    Ensure-Manifest -PublicDir $publicDir -AppName $appName -ShortName $name

    $baseUrl = "https://truvern.com"
    Ensure-Robots-Sitemap -PublicDir $publicDir -BaseUrl $baseUrl
    Write-Host ("Assets ensured for {0}" -f $name) -ForegroundColor Green
  }
}

# ----------------------- Install deps ------------------------------------
Write-Host "Step 3/6: Installing dependencies (pnpm install) ..." -ForegroundColor Cyan
& pnpm install --frozen-lockfile | Out-Null
Write-Host "Dependencies installed." -ForegroundColor Green

# ----------------------- Build all workspaces ----------------------------
Write-Host "Step 4/6: Building all workspaces (pnpm -r run build) ..." -ForegroundColor Cyan
# Use recursive to build every package that has "build" script
& pnpm -r run build
Write-Host "Build step finished." -ForegroundColor Green

# ----------------------- Verify CSS outputs ------------------------------
Write-Host "Step 5/6: Verifying CSS emission ..." -ForegroundColor Cyan
$verifications = @()
if ($apps -and $apps.Count -gt 0) {
  foreach ($app in $apps) {
    $result = Verify-CSS -AppDir $app
    $verifications += $result
    $name = Split-Path $app -Leaf
    if ($result.ok) {
      Write-Host ("CSS OK for {0} ({1})" -f $name, $result.reason) -ForegroundColor Green
    } else {
      Write-Host ("CSS MISSING for {0} ({1})" -f $name, $result.reason) -ForegroundColor Yellow
    }
  }
} else {
  Write-Host "No app directories discovered to verify." -ForegroundColor Yellow
}

# ----------------------- Summary ----------------------------------------
Write-Host ""
Write-Host "Step 6/6: Summary" -ForegroundColor Cyan

# Safety: coerce collections into arrays
if (-not $apps) { $apps = @() }
if (-not $verifications) { $verifications = @() }

$appsCount      = @($apps).Count
$cssOkCount     = (@($verifications | Where-Object { $_.ok })).Count
$cssTotal       = (@($verifications)).Count

Write-Host ("Apps discovered: {0}" -f $appsCount) -ForegroundColor White
Write-Host ("CSS verified OK: {0} of {1}" -f $cssOkCount, $cssTotal) -ForegroundColor White

if ($cssTotal -gt 0 -and $cssOkCount -eq $cssTotal) {
    Write-Host "UI polish and build verification PASSED." -ForegroundColor Green
}
elseif ($cssTotal -eq 0) {
    Write-Host "UI polish complete (no app directories found to verify)." -ForegroundColor Yellow
}
else {
    Write-Host "UI polish complete; some CSS outputs not found. Review warnings above." -ForegroundColor Yellow
}

Write-Host ("Log saved to: {0}" -f $LogPath) -ForegroundColor DarkGray
Stop-Transcript | Out-Null
