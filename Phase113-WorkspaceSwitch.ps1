# ================================
# Phase113-WorkspaceSwitch.ps1 (fixed)
# ================================

$ErrorActionPreference = "Stop"

# Use a safe variable name (not $HOME)
$userHome = Join-Path $env:USERPROFILE ""

# 1) Find candidate base directories
$bases = @(
  (Join-Path $userHome "Downloads\Nelson AI Projects"),
  (Join-Path $userHome "Downloads\Nelson AI Projectss"),
  (Join-Path $userHome "Nelson AI Projects"),
  (Join-Path $userHome "Nelson AI Projectss")
) | Get-Unique

# --- Find candidate truvern folders safely ---
$found = @()
foreach ($b in $bases) {
  if (Test-Path $b) {
    $t = Get-ChildItem -Path $b -Recurse -Directory -Filter "truvern" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($t) {
      $found += [PSCustomObject]@{ Base = $b; Truvern = $t.FullName }
    }
  }
}

if (-not $found) { throw "Could not find any 'truvern' repo under *Nelson AI Project[s]* folders." }

# 2) Choose canonical (without the extra 's')
$canonicalBase = ($found.Base | Where-Object { $_ -match "Nelson AI Projects($|\\)" } | Select-Object -First 1)
if (-not $canonicalBase) {
  # Create canonical base if only the typo exists
  $canonicalBase = (Join-Path ($home) "Downloads\Nelson AI Projects")
  if (!(Test-Path $canonicalBase)) { New-Item $canonicalBase -ItemType Directory | Out-Null }
}
$canonicalTruvern = Join-Path $canonicalBase "truvern"

# 3) Identify a source repo to sync from (newest truvern by LastWriteTime)
$allTruvern = $found.Truvern | ForEach-Object {
  $stamp = (Get-ChildItem -Path $_ -Recurse -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1).LastWriteTime
  [PSCustomObject]@{ Path = $_; LastWrite = $stamp }
} | Sort-Object LastWrite -Descending

$sourceRepo = $allTruvern[0].Path
Write-Host "Source repo: $sourceRepo" -ForegroundColor Cyan
Write-Host "Canonical repo: $canonicalTruvern" -ForegroundColor Cyan

# 4) Clean heavy artifacts in source to avoid copying garbage
$toClean = @(".next","node_modules",".turbo","dist","build")
foreach ($d in $toClean) {
  $p = Join-Path $sourceRepo $d
  if (Test-Path $p) { Write-Host "Cleaning $p" -ForegroundColor DarkGray; Remove-Item $p -Recurse -Force -ErrorAction SilentlyContinue }
}

# 5) Backup canonical if it already exists, then sync from source → canonical
if (Test-Path $canonicalTruvern) {
  $bak = "$canonicalTruvern.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
  Write-Host "Backing up existing canonical to $bak" -ForegroundColor Yellow
  Copy-Item $canonicalTruvern $bak -Recurse -Force
} else {
  New-Item $canonicalTruvern -ItemType Directory | Out-Null
}

# Use robocopy for robust sync (exclude node_modules/.next)
$ro = @("$sourceRepo", "$canonicalTruvern", "/MIR", "/XD", "node_modules", ".next", ".turbo", "dist", "build", "/NFL", "/NDL", "/NJH", "/NJS", "/NP", "/R:2", "/W:2")
& robocopy @ro | Out-Null
Write-Host "Synced source → canonical." -ForegroundColor Green

# 6) Move into canonical repo; ensure we never run from System32
Set-Location $canonicalTruvern
if ($PWD.Path -match "Windows\\System32") { throw "Refusing to run from System32. cd into: $canonicalTruvern" }

# 7) Force fresh Vercel link (clean .vercel and relink)
$vercelFolder = Join-Path $PWD ".vercel"
if (Test-Path $vercelFolder) { Remove-Item $vercelFolder -Recurse -Force -ErrorAction SilentlyContinue }
mkdir .vercel | Out-Null

# Make sure pnpm/node/vercel are in PATH
try { pnpm -v | Out-Null } catch { throw "pnpm not found in PATH" }
try { vercel --version | Out-Null } catch { throw "Vercel CLI not found in PATH" }

# Link to the correct project (truvern)
vercel link --yes --project truvern | Out-Null

# 8) Install, build, deploy
if (Test-Path ".env.production.local") { Write-Host "Found .env.production.local" -ForegroundColor DarkGray }
pnpm install
pnpm build

$deployOut = vercel --prod --yes --force
$deployed = ($deployOut | Select-String -Pattern '\S+\.vercel\.app' -AllMatches).Matches.Value | Select-Object -Last 1
if (-not $deployed) { throw "Could not determine deployed URL from vercel output." }

# 9) Alias main domains
vercel alias set $deployed truvern.com     | Out-Null
vercel alias set $deployed www.truvern.com | Out-Null
Write-Host "Aliased truvern.com → $deployed" -ForegroundColor Green

# 10) Smoke tests
$urls = @(
  "https://truvern.com/",
  "https://truvern.com/trust-network",
  "https://truvern.com/vendors",
  "https://truvern.com/pricing",
  "https://truvern.com/contact",
  "https://truvern.com/api/vendors",
  "https://truvern.com/api/board",
  "https://truvern.com/api/trust-network"
)

foreach ($u in $urls) {
  try {
    $r = Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 20
    Write-Host ("OK {0} -> HTTP {1}" -f $u,$r.StatusCode) -ForegroundColor Green
  }
  catch {
    $c = $_.Exception.Response.StatusCode.value__ 2>$null
    if ($c) {
      Write-Host ("WARN {0} -> HTTP {1}" -f $u,$c) -ForegroundColor DarkYellow
    } else {
      Write-Host ("FAIL {0} -> {1}" -f $u,$_.Exception.Message) -ForegroundColor Red
    }
  }
}
