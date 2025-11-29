# ======================================================================
# Phase93-ClientNullGuard-Clean.ps1
# Hardens React code that assumes vendors is always present.
# - Guards .map() and .length usages
# - Adds app/lib/safe.ts helper
# - Builds, deploys to Vercel prod, aliases truvern.com and www
# - Verifies key URLs
# ======================================================================

[CmdletBinding()]
param(
  [string]$Root = (Get-Location).Path,
  [string]$VercelProject = "truvern",
  [string]$Domain = "truvern.com",
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"

function Find-AppDir {
  param([string]$base)
  $p1 = Join-Path $base "apps\tprm\app"
  $p2 = Join-Path $base "app"
  $p3 = Join-Path $base "apps\website\app"
  if (Test-Path $p1) { return (Resolve-Path $p1).Path }
  if (Test-Path $p2) { return (Resolve-Path $p2).Path }
  if (Test-Path $p3) { return (Resolve-Path $p3).Path }
  throw "No Next.js app dir found. Tried: `n  $p1`n  $p2`n  $p3"
}

function Write-Utf8File {
  param([string]$Path,[string]$Content)
  [System.IO.File]::WriteAllText($Path,$Content,[System.Text.UTF8Encoding]::new($false))
}

# --- logging -----------------------------------------------------------
if (-not (Test-Path (Join-Path $Root "logs"))) { New-Item -ItemType Directory -Path (Join-Path $Root "logs") | Out-Null }
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logPath = Join-Path $Root ("logs\Phase93-" + $stamp + ".log")
Start-Transcript -Path $logPath -Append | Out-Null

try {
  # --- locate app dir --------------------------------------------------
  $appDir = Find-AppDir -base $Root
  Write-Host "App dir: $appDir"

  # --- list candidate files -------------------------------------------
  $all = Get-ChildItem -Path $appDir -Recurse -Include *.tsx,*.ts -File
  $exclude = '\node_modules\', '\.next\', '\dist\', '\build\', '\prisma\', '\.vercel\'
  $files = $all | Where-Object {
    $p = $_.FullName.ToLowerInvariant()
    ($exclude | Where-Object { $p -like "*$_*" }).Count -eq 0 -and
    ($p -like "*\app\*" -or $p -like "*\components\*")
  }

  Write-Host ("Files to scan: {0}" -f $files.Count)

  # --- helper file -----------------------------------------------------
  $libDir = Join-Path $appDir "lib"
  if (-not (Test-Path $libDir)) { New-Item -ItemType Directory -Path $libDir | Out-Null }
  $helperPath = Join-Path $libDir "safe.ts"
  $helperCode = @'
export function safeVendors(input: any): any[] {
  if (Array.isArray(input?.vendors)) return input.vendors;
  if (Array.isArray(input)) return input;
  return [];
}
'@
  if (-not $DryRun) { Write-Utf8File -Path $helperPath -Content $helperCode }
  Write-Host "Ensured helper: $helperPath"

  # --- regex patches ---------------------------------------------------
  $changed = 0
  foreach ($f in $files) {
    $content = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8
    $orig = $content

    # 1) obj.vendors.map(  ->  (( obj?.vendors ?? [] )).map(
    $content = [regex]::Replace($content, '(\b[\w$]+)\.vendors\.map\(', '(( $1?.vendors ?? [] )).map(')

    # 2) obj.vendors.length -> (( obj?.vendors ?? [] )).length
    $content = [regex]::Replace($content, '(\b[\w$]+)\.vendors\.length\b', '(( $1?.vendors ?? [] )).length')

    # 3) vendors.map( -> (( vendors ?? [] )).map(
    $content = $content -replace '\bvendors\.map\(', '(( vendors ?? [] )).map('

    # 4) vendors.length -> (( vendors ?? [] )).length
    $content = $content -replace '\bvendors\.length\b', '(( vendors ?? [] )).length'

    # 5) data && data.vendors.map( -> (( data?.vendors ?? [] )).map(
    $content = [regex]::Replace($content, '(\b[\w$]+)\s*&&\s*\1\.vendors\.map\(', '(( $1?.vendors ?? [] )).map(')

    if ($content -ne $orig) {
      $changed++
      if (-not $DryRun) {
        Copy-Item -LiteralPath $f.FullName -Destination ($f.FullName + ".bak") -Force
        Write-Utf8File -Path $f.FullName -Content $content
      }
      Write-Host "Patched: $($f.FullName)"
    }
  }

  if ($changed -eq 0) { Write-Host "No changes needed." } else { Write-Host ("Patched files: {0}" -f $changed) }

  if ($DryRun) {
    Write-Host "DryRun enabled: build/deploy skipped."
    Stop-Transcript | Out-Null
    exit 0
  }

  # --- build -----------------------------------------------------------
  Write-Host "Installing and building..."
  pnpm install
  pnpm build

  # --- deploy ----------------------------------------------------------
  Write-Host "Deploying to Vercel Production..."
  $deployOut = vercel --prod --yes

  $deployed = ($deployOut | Select-String -Pattern 'https://[^\s"]+\.vercel\.app' -AllMatches).Matches.Value | Select-Object -Last 1
  if (-not $deployed) {
    $deployed = (vercel ls --prod | Select-String -Pattern '\S+\.vercel\.app' -AllMatches).Matches.Value | Select-Object -First 1
  }
  if ($deployed) {
    Write-Host "Production deployment: $deployed"
    Write-Host "Aliasing $Domain and www.$Domain ..."
    vercel alias set $deployed $Domain | Out-Null
    vercel alias set $deployed ("www." + $Domain) | Out-Null
  } else {
    Write-Host "Warning: Could not determine deployment URL; alias step skipped."
  }

  # --- verify ----------------------------------------------------------
  $base = "https://$Domain"
  $urls = @("$base/","$base/trust-network","$base/api/board")
  Write-Host "Live URL checks:"
  foreach ($u in $urls) {
    try {
      $r = Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 20
      Write-Host ("OK {0} -> HTTP {1}" -f $u, $r.StatusCode)
    } catch {
      $code = $_.Exception.Response.StatusCode.value__ 2>$null
      if ($code) { Write-Host ("WARN {0} -> HTTP {1}" -f $u,$code) }
      else { Write-Host ("FAIL {0} unreachable: {1}" -f $u, $_.Exception.Message) }
    }
  }

  Stop-Transcript | Out-Null
  exit 0

} catch {
  Write-Host ("ERROR: {0}" -f $_.Exception.Message)
  if ($_.ScriptStackTrace) { Write-Host $_.ScriptStackTrace }
  try { Stop-Transcript | Out-Null } catch {}
  exit 1
}
