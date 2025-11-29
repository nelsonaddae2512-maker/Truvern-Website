<# ====================== Phase119c-SafeDeploy.ps1 =======================
 Safe deploy + alias + endpoint checks, without false failures from
 "Environment variables loaded from .env" and without touching $HOME.
------------------------------------------------------------------------- #>

[CmdletBinding()]
param(
  [switch]$NoDeploy,   # if set, skip Vercel deploy (useful for dry-runs)
  [switch]$NoAlias,    # if set, skip aliasing
  [string]$Domain = "truvern.com"
)

# ---------- tiny console helpers ----------
function Write-Info($m){ Write-Host $m -ForegroundColor Cyan }
function Write-Good($m){ Write-Host $m -ForegroundColor Green }
function Write-Warn($m){ Write-Host $m -ForegroundColor DarkYellow }
function Write-Err ($m){ Write-Host $m -ForegroundColor Red }
function Fail($m){ Write-Err "ERROR: $m"; throw $m }

# ---------- workspace sanity ----------
$root = Get-Location
Write-Info "Working dir: $($root.Path)"
if (!(Test-Path package.json)) { Fail "package.json not found here. Run this from your repo root." }

# ---------- logging (no auto-close) ----------
if (-not (Test-Path ".\logs")) { New-Item -ItemType Directory -Path ".\logs" | Out-Null }
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$log   = ".\logs\Phase119c-$stamp.log"
try { Stop-Transcript | Out-Null } catch {}
Start-Transcript -Path $log -Force | Out-Null
Write-Info "Logging to: $log"

try {
  # ---------- ensure pnpm ----------
  if (-not (Get-Command pnpm -ErrorAction SilentlyContinue)) {
    Fail "pnpm is not on PATH. Install with: corepack enable; corepack prepare pnpm@latest --activate"
  }

  # ---------- install + prisma generate ----------
  Write-Info "Installing dependencies (pnpm i)…"
  pnpm i
  if ($LASTEXITCODE -ne 0) { Fail "pnpm install failed with exit code $LASTEXITCODE" }

  Write-Info "Generating Prisma client (prisma generate)…"
  pnpm prisma generate
  if ($LASTEXITCODE -ne 0) { Fail "prisma generate failed with exit code $LASTEXITCODE" }

  # ---------- build (ignore benign Prisma ‘Environment variables loaded from .env’) ----------
  Write-Info "Building Next.js app (pnpm run build)…"
  pnpm run build
  $buildCode = $LASTEXITCODE
  if ($buildCode -ne 0) { Fail "pnpm build exited with code $buildCode" }
  Write-Good "Local build finished."

  # ---------- locate vercel CLI (use vercel.cmd, avoid PS shim issues) ----------
  function Resolve-VercelPath {
    $cmd = Get-Command vercel -ErrorAction SilentlyContinue
    if ($cmd) {
      # Prefer the .cmd shim if both exist
      $p = $cmd.Path
      if ($p -like "*.ps1") {
        $guess = $p -replace "\.ps1$",".cmd"
        if (Test-Path $guess) { return $guess }
      }
      return $p
    }
    # common global npm path
    $candidate = Join-Path $env:APPDATA "npm\vercel.cmd"
    if (Test-Path $candidate) { return $candidate }
    return $null
  }

  $vercelPath = Resolve-VercelPath
  if (-not $vercelPath) { Fail "Vercel CLI not found. Install with: npm i -g vercel" }
  Write-Info ("Using Vercel CLI at: {0}" -f $vercelPath)

  # helper invoker to avoid PS parsing quirks
  function Invoke-Vercel([string[]]$args) {
    & $vercelPath @args
    if ($LASTEXITCODE -ne 0) {
      Fail ("vercel {0} exited with code {1}" -f ($args -join ' '), $LASTEXITCODE)
    }
  }

  # ---------- deploy (optional bypass with -NoDeploy) ----------
  $deployUrl = $null
  if (-not $NoDeploy) {
    Write-Info "Deploying with Vercel (prod)…"
    $out = & $vercelPath "--prod" "--yes"
    $code = $LASTEXITCODE
    if ($code -ne 0) { Fail "vercel --prod --yes failed with code $code" }

    # parse the deployment URL from output (…vercel.app)
    $m = [regex]::Matches(($out -join "`n"), "https?://[a-z0-9-]+\.vercel\.app", 'IgnoreCase')
    if ($m.Count -gt 0) { $deployUrl = $m[$m.Count-1].Value }
    if (-not $deployUrl) { Write-Warn "Could not determine deployment URL from vercel output. Continuing." }
    else { Write-Good ("Deployed: {0}" -f $deployUrl) }
  } else {
    Write-Warn "Skipping deploy (NoDeploy switch set)."
  }

  # ---------- alias main domains (optional bypass with -NoAlias) ----------
  if (-not $NoAlias) {
    if (-not $deployUrl) {
      # try to pick the most recent Ready production deployment
      Write-Info "Picking latest Ready production deployment for alias…"
      $ls = & $vercelPath "ls" "--prod"
      $readyLines = ($ls -join "`n") -split "`n" | Where-Object { $_ -match "Ready" -and $_ -match "\.vercel\.app" }
      if ($readyLines.Count -gt 0) {
        $last = $readyLines[-1]
        $m2 = [regex]::Match($last, "https?://[a-z0-9-]+\.vercel\.app", 'IgnoreCase')
        if ($m2.Success) { $deployUrl = $m2.Value }
      }
    }

    if ($deployUrl) {
      Write-Info ("Aliasing {0} -> {1}" -f $Domain, $deployUrl)
      Invoke-Vercel @("alias","set",$deployUrl,$Domain)

      $www = "www.$Domain"
      Write-Info ("Aliasing {0} -> {1}" -f $www, $deployUrl)
      Invoke-Vercel @("alias","set",$deployUrl,$www)
    } else {
      Write-Warn "No deployment URL available to alias."
    }
  } else {
    Write-Warn "Skipping alias (NoAlias switch set)."
  }

  # ---------- endpoint smoke tests ----------
  $base = "https://$Domain"
  $routes = @(
    "$base/",
    "$base/trust-network",
    "$base/vendors",
    "$base/pricing",
    "$base/contact",
    "$base/api/vendors",
    "$base/api/board",
    "$base/api/trust-network"
  )

  Write-Info "Verifying site endpoints."
  foreach ($u in $routes) {
    try {
      $r = Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 15
      Write-Good ("OK {0} -> HTTP {1}" -f $u,$r.StatusCode)
    } catch {
      Write-Warn ("WARN {0} -> {1}" -f $u,$_.Exception.Message)
    }
  }

  # ---------- API spot check expects JSON ----------
  foreach ($api in @("$base/api/vendors","$base/api/board","$base/api/trust-network")) {
    try {
      $r = Invoke-WebRequest -Uri $api -UseBasicParsing -TimeoutSec 15
      $t = $r.Content.Trim()
      if ($t.StartsWith('{') -or $t.StartsWith('[')) {
        Write-Good ("API looks good: {0}" -f $api)
      } else {
        Write-Warn ("API returned non-JSON-ish content: {0}" -f $api)
      }
    } catch {
      Write-Warn ("API check failed {0} -> {1}" -f $api,$_.Exception.Message)
    }
  }

  Write-Good "Phase119c complete."

} catch {
  Fail $_.Exception.Message
} finally {
  try { Stop-Transcript | Out-Null } catch {}
  Write-Info "Log: $log"
  [void](Read-Host "Press ENTER to close this window")
}
