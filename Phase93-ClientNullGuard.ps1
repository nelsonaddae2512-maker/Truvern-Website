<# ===========================================================================
 Phase93-ClientNullGuard.ps1
 Goal:
   - Patch common React/Next patterns that assume `vendors` always exists
     so they use safe guards: (data?.vendors ?? [])
   - Add a small helper (lib/safe.ts)
   - Rebuild, deploy to Vercel Production, alias truvern.com, verify routes

 NOTES:
   - This is conservative: it only touches .tsx/.ts in app/ and component dirs
     and skips node_modules, .next, prisma, build, dist.
   - Creates a .\logs\Phase93-*.log transcript and .bak backups for any edits.
 ============================================================================ #>

[CmdletBinding()]
param(
  [string]$Root = (Get-Location).Path,
  [string]$VercelProject = "truvern",
  [string]$Domain = "truvern.com",
  [switch]$DryRun  # show planned changes without saving
)

$ErrorActionPreference = 'Stop'

# --- logging ---
if (-not (Test-Path "$Root\logs")) { New-Item -ItemType Directory -Path "$Root\logs" | Out-Null }
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$log = "$Root\logs\Phase93-$stamp.log"
Start-Transcript -Path $log -Append | Out-Null

function Finish([int]$code) {
  try { Stop-Transcript | Out-Null } catch {}
  Write-Host "`n📄 Log: $log" -ForegroundColor Yellow
  exit $code
}

# --- helpers ---
function Find-AppDir([string]$base) {
  $p1 = Join-Path $base "apps\tprm\app"
  $p2 = Join-Path $base "app"
  $p3 = Join-Path $base "apps\website\app"
  foreach ($p in @($p1,$p2,$p3)) { if (Test-Path $p) { return (Resolve-Path $p).Path } }
  throw "No Next.js app dir found. Tried: `n  $p1`n  $p2`n  $p3"
}
function SafeWrite([string]$path,[string]$content,[switch]$NoBackup){
  if (-not $NoBackup -and -not $DryRun) { Copy-Item $path "$path.bak" -Force }
  if (-not $DryRun) { [IO.File]::WriteAllText($path,$content,[Text.UTF8Encoding]::new($false)) }
}

# --- locate app dir and candidate files ---
$appDir = Find-AppDir $Root
Write-Host "📁 App dir: $appDir" -ForegroundColor Yellow

$excludeDirs = @("\node_modules\", "\.next\", "\dist\", "\build\", "\prisma\", "\.vercel\")
$files = Get-ChildItem -Path $appDir -Recurse -Include *.tsx,*.ts |
  Where-Object { ($excludeDirs | Where-Object { $_ -and $_ -ne "" -and $_ -in $_.FullName }) -eq $null }

# Keep it focused to pages/components only
$files = $files | Where-Object {
  $_.DirectoryName -match '\\app\\' -or $_.DirectoryName -match '\\components\\'
}

Write-Host ("🔎 Files to scan: {0}" -f $files.Count)

# --- tiny helper (non-breaking) ---
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
if (-not (Test-Path $helperPath)) {
  if (-not $DryRun) { [IO.File]::WriteAllText($helperPath,$helperCode,[Text.UTF8Encoding]::new($false)) }
  Write-Host "✍️  Added helper: $helperPath"
} else {
  Write-Host "ℹ️  Helper already exists: $helperPath"
}

# --- regex patch set ---
# 1) X.vendors.map(   ->   ((X?.vendors ?? [])).map(
$rxMap = [regex]'(?<![\w$])([A-Za-z0-9_$]+)\.vendors\.map\('
$reMap = '(( $1?.vendors ?? [] )).map('

# 2) X.vendors.length -> ((X?.vendors ?? [])).length
$rxLen = [regex]'(?<![\w$])([A-Za-z0-9_$]+)\.vendors\.length(?!\w)'
$reLen = '(( $1?.vendors ?? [] )).length'

# 3) bare vendors.map( -> ( (vendors ?? []) ).map(
$rxBareMap = [regex]'(?<![\w$])vendors\.map\('
$reBareMap = '(( vendors ?? [] )).map('

# 4) bare vendors.length -> ( (vendors ?? []) ).length
$rxBareLen = [regex]'(?<![\w$])vendors\.length(?!\w)'
$reBareLen = '(( vendors ?? [] )).length'

# 5) optional: replace common guards like `data && data.vendors.map(` -> `((data?.vendors ?? [])).map(`
$rxAndMap = [regex]'(?<![\w$])([A-Za-z0-9_$]+)\s*&&\s*\1\.vendors\.map\('
$reAndMap = '(( $1?.vendors ?? [] )).map('

$changed = 0
$patched = @()

foreach ($f in $files) {
  $original = [IO.File]::ReadAllText($f.FullName)
  $updated  = $original

  $updated = $rxMap.Replace($updated,$reMap)
  $updated = $rxLen.Replace($updated,$reLen)
  $updated = $rxBareMap.Replace($updated,$reBareMap)
  $updated = $rxBareLen.Replace($updated,$reBareLen)
  $updated = $rxAndMap.Replace($updated,$reAndMap)

  if ($updated -ne $original) {
    $changed++
    $patched += $f.FullName
    Write-Host "🛠️  Patching: $($f.FullName)"
    SafeWrite $f.FullName $updated
  }
}

if ($changed -eq 0) {
  Write-Host "✅ No unsafe vendor usages found (nothing to patch)." -ForegroundColor Green
} else {
  Write-Host "✅ Patched $changed file(s)." -ForegroundColor Green
}

if ($DryRun) {
  Write-Host "`n(DRY RUN) Changes were NOT saved. Re-run without -DryRun to apply." -ForegroundColor Yellow
  Finish 0
}

# --- build & deploy ---
Write-Host "`n📦 Installing & building..." -ForegroundColor Yellow
pnpm install
pnpm build

Write-Host "🚀 Deploying to Vercel Production..." -ForegroundColor Yellow
$deployOut = vercel --prod --yes
$deployOut | Out-File -Encoding utf8 "$Root\logs\Phase93-deploy-$stamp.txt"

# Extract newest prod URL
$deployed = ($deployOut | Select-String -Pattern '\S+\.vercel\.app' -AllMatches).Matches.Value | Select-Object -Last 1
if (-not $deployed) {
  $deployed = (vercel ls --prod | Select-String -Pattern '\S+\.vercel\.app' -AllMatches).Matches.Value | Select-Object -First 1
}
if ($deployed) {
  Write-Host "✅ Production deployment: $deployed"
  Write-Host "🔗 Aliasing $Domain and www.$Domain..." -ForegroundColor Yellow
  vercel alias set $deployed $Domain | Out-Null
  vercel alias set $deployed "www.$Domain" | Out-Null
} else {
  Write-Host "⚠️ Could not resolve deployed URL automatically; skipping alias." -ForegroundColor DarkYellow
}

# --- verify live site ---
$base = "https://$Domain"
$urls = @("$base/","$base/trust-network","$base/api/board")
Write-Host "`n===== Live URL checks =====" -ForegroundColor Yellow
foreach ($u in $urls) {
  try {
    $r = Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 20
    Write-Host "✅ $u → HTTP $($r.StatusCode)" -ForegroundColor Green
  } catch {
    $code = $_.Exception.Response.StatusCode.value__ 2>$null
    if ($code) { Write-Host "⚠️ $u → HTTP $code" -ForegroundColor DarkYellow }
    else       { Write-Host "❌ $u unreachable: $($_.Exception.Message)" -ForegroundColor Red }
  }
}

Finish 0
