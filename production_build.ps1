# =======================
# Truvern: Production Build & Deploy
# =======================

if ($pwd.Path -match '\\Windows\\System32($|\\)') {
  Set-Location "$env:USERPROFILE\Downloads\truvern"
}

$env:CI = "true"
$logDir = Join-Path (Get-Location) 'logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$log = Join-Path $logDir "production_build_$stamp.log"

function Write-Log([string]$m) { Add-Content -Path $log -Value $m -Encoding UTF8; Write-Host $m }
function Run-Step([string]$title, [scriptblock]$action) {
  Write-Host "`n==> $title"
  & $action *>> $log
  if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) { throw "Step failed ($title). Exit code: $LASTEXITCODE" }
  if (-not $?) { throw "Step failed ($title). PowerShell error" }
  Write-Host "<== $title : OK"
}

Write-Log ("BEGIN {0:yyyy-MM-dd HH:mm:ss}" -f (Get-Date))
Write-Log ("PWD  : {0}" -f (Get-Location))

# --- Load DATABASE_URL from .env.production.local ---
$envFile = ".env.production.local"
if (-not (Test-Path $envFile)) { $envFile = ".env" }
if (Test-Path $envFile) {
  (Get-Content $envFile) | ForEach-Object {
    if ($_ -match '^\s*DATABASE_URL\s*=\s*(.+)\s*$') {
      $env:DATABASE_URL = $matches[1].Trim('"').Trim("'")
      Write-Log "DATABASE_URL loaded from $envFile"
    }
  }
}
if (-not $env:DATABASE_URL) { throw "DATABASE_URL not set. Add to .env.production.local or .env" }

# --- Install dependencies ---
$usePnpm = Test-Path "pnpm-lock.yaml"
if ($usePnpm) {
  Run-Step "Install dependencies" { pnpm install --frozen-lockfile --reporter=silent }
} else {
  Run-Step "Install dependencies" { npm ci --no-audit --no-fund }
}

# --- Prisma ---
if (Test-Path "prisma\schema.prisma") {
  Run-Step "Prisma generate" { npx --yes prisma generate }
  Run-Step "Prisma migrate deploy" { npx --yes prisma migrate deploy }
}

# --- Build ---
if (Test-Path "turbo.json") {
  if ($usePnpm) { Run-Step "Build (turbo/pnpm)" { pnpm turbo run build } }
  else { Run-Step "Build (turbo/npm)" { npx turbo run build } }
} else {
  if ($usePnpm) { Run-Step "Build (pnpm)" { pnpm run build } }
  else { Run-Step "Build (npm)" { npm run build } }
}

# --- Deploy ---
$vercelToken = $env:VERCEL_TOKEN
if (-not (Test-Path ".vercel")) {
  if ($vercelToken) { Run-Step "Vercel link (token)" { vercel link --yes --token $vercelToken } }
  else { Run-Step "Vercel link (CLI)" { vercel link --yes } }
}
if ($vercelToken) { Run-Step "Vercel deploy (prod, token)" { vercel --prod --yes --token $vercelToken } }
else { Run-Step "Vercel deploy (prod)" { vercel --prod --yes } }

Write-Log ("END {0:yyyy-MM-dd HH:mm:ss}" -f (Get-Date))
Write-Host "`n✅ All done. Log: $log" -ForegroundColor Green
