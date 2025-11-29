# Phase124c-TeamRebind.ps1
# Relink local project to the correct Vercel team and deploy safely.
# Tested for Windows PowerShell 5+ (no fancy ANSI features).

$ErrorActionPreference = 'Stop'

# ---- USER SETTINGS (edit if your slug differs) ----
$teamSlug     = 'nelson-ai-projects'     # Vercel team slug (usually lowercase with dashes)
$projectName  = 'truvern'                # Vercel project name
$baseFallback = 'https://truvern.com'    # fallback for verification if production URL parsing fails

# ---- Guard: must run from the project folder, not System32 ----
try { $PWD = (Get-Location).Path } catch {}
if (Test-Path "C:\Windows\System32") {
  if ($PWD -match '\\Windows\\System32$') {
    Write-Host "❌ Do not run from System32. cd into your project folder (truvern) and rerun." -ForegroundColor Red
    exit 1
  }
}

# ---- Logs ----
$ts      = Get-Date -Format "yyyyMMdd-HHmmss"
$logDir  = Join-Path $PWD "logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$mainLog = Join-Path $logDir "phase124c-main-$ts.log"
$depLog  = Join-Path $logDir "phase124c-deploy-$ts.txt"
$vrfLog  = Join-Path $logDir "route-public-verify-$ts.txt"

Function Log($msg, $color='Gray') {
  Write-Host $msg -ForegroundColor $color
  Add-Content -Path $mainLog -Value $msg
}

Log "=== Phase124c: Team relink -> build -> deploy -> verify ===" 'Cyan'
Log "Team slug  : $teamSlug"
Log "Project    : $projectName"
Log "Logs       : $mainLog`n           $depLog`n           $vrfLog"

# ---- Ensure pnpm & vercel are on PATH (Windows global npm bin) ----
$npmBin = Join-Path $env:APPDATA "npm"
$pnpmCmd = Join-Path $npmBin "pnpm.cmd"
$vercelCmd = Join-Path $npmBin "vercel.cmd"

if (-not (Get-Command pnpm -ErrorAction SilentlyContinue)) {
  if (Test-Path $pnpmCmd) { $env:Path += ";$npmBin" }
}
if (-not (Get-Command vercel -ErrorAction SilentlyContinue)) {
  if (Test-Path $vercelCmd) { $env:Path += ";$npmBin" }
}

# Show resolved CLI versions
try {
  $pnpmV = (pnpm -v) 2>$null
  Log "pnpm  = $pnpmV" 'DarkGray'
} catch {}
try {
  $vercelV = (vercel -v) 2>$null
  Log "vercel= $vercelV" 'DarkGray'
} catch {}

# ---- Backup existing .vercel link (if present) ----
$vercelDir = Join-Path $PWD ".vercel"
if (Test-Path $vercelDir) {
  $bak = "$vercelDir.bak-$ts"
  Log "Backing up .vercel -> $bak" 'Yellow'
  Rename-Item -Path $vercelDir -NewName (".vercel.bak-$ts") -Force
}

# ---- Install deps (frozen lockfile to avoid churn) ----
Log "Installing dependencies (pnpm i --frozen-lockfile)..." 'Cyan'
cmd /c "pnpm i --frozen-lockfile" 2>&1 | Tee-Object -FilePath $mainLog -Append | Out-Host

# ---- Link to correct team (non-interactive) ----
Log "Linking project to correct team scope..." 'Cyan'
# vercel link will recreate .vercel/ and write project linkage
# --yes accepts defaults; --project picks the slug/name; --scope enforces the team
cmd /c "vercel link --yes --project $projectName --scope $teamSlug" 2>&1 | Tee-Object -FilePath $mainLog -Append | Out-Host

# Optional sanity: list envs to confirm scope is valid (won't fail the script if perms differ)
try {
  cmd /c "vercel env ls --environment production --scope $teamSlug" 2>&1 | Tee-Object -FilePath $mainLog -Append | Out-Host
} catch { }

# ---- Build (local) ----
Log "Building project (pnpm run build)..." 'Cyan'
cmd /c "pnpm run build" 2>&1 | Tee-Object -FilePath $mainLog -Append | Out-Host

# ---- Deploy (prod) with scope ----
Log "Deploying to Vercel (prod) with --scope=$teamSlug ..." 'Cyan'
Remove-Item -Force -ErrorAction SilentlyContinue $depLog
cmd /c "vercel --prod --yes --scope $teamSlug" 2>&1 | Tee-Object -FilePath $depLog -Append | Out-Host

# ---- Parse Production URL from deploy output ----
$prodUrl = $null
try {
  $lines = Get-Content $depLog
  # Look for a line containing 'Production:' followed by an https URL
  $urlLine = $lines | Where-Object { $_ -match 'Production:\s+(https://[^\s]+)' } | Select-Object -Last 1
  if ($urlLine) {
    $m = [regex]::Match($urlLine, 'https://[^\s]+')
    if ($m.Success) { $prodUrl = $m.Value }
  }
} catch {}

if (-not $prodUrl) {
  Log "Could not detect production URL from deploy output. Falling back to $baseFallback" 'Yellow'
  $prodUrl = $baseFallback
}
Log "Production URL: $prodUrl" 'Green'

# ---- Verify public routes (only public; auth pages may return 401 by design) ----
$routes = @('/', '/pricing', '/login', '/subscribe', '/api/health', '/favicon.ico', '/manifest.json')
$okAll = $true
"Base: $prodUrl" | Tee-Object -FilePath $vrfLog -Append | Out-Host
foreach ($r in $routes) {
  try {
    $u = ($prodUrl.TrimEnd('/')) + $r
    $t0 = Get-Date
    $res = Invoke-WebRequest -UseBasicParsing -Method GET -Uri $u -TimeoutSec 20
    $ms = [int]((Get-Date) - $t0).TotalMilliseconds
    if ($res.StatusCode -eq 200) {
      $line = "OK  $u -> 200 ($ms ms)"
      Write-Host $line -ForegroundColor Green
      Add-Content -Path $vrfLog -Value $line
    } else {
      $line = "ERR $u -> $($res.StatusCode)"
      Write-Host $line -ForegroundColor Yellow
      Add-Content -Path $vrfLog -Value $line
      $okAll = $false
    }
  } catch {
    $line = "ERR $u -> $($_.Exception.Message)"
    Write-Host $line -ForegroundColor Red
    Add-Content -Path $vrfLog -Value $line
    $okAll = $false
  }
}

if ($okAll) {
  Log "✅ All public routes returned HTTP 200." 'Green'
} else {
  Log "⚠️  Some public routes failed. See $vrfLog" 'Yellow'
}

Log "Main log : $mainLog" 'DarkGray'
Log "Deploy   : $depLog"  'DarkGray'
Log "Verify   : $vrfLog"  'DarkGray'
Write-Host ""
Read-Host "Press Enter to close"
