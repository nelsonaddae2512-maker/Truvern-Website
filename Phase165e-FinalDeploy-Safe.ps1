param(
    [string]$ProjectDir = "C:\Users\MR.NELSON\Downloads\truvern"
)

# ============================================
# Phase165e: FINAL DEPLOY (SAFE, CMD-BASED)
# ============================================

# Don't let PowerShell treat native stderr as fatal
$ErrorActionPreference = "Continue"

function Info($m) { Write-Host "[INFO]  $m" }
function Warn($m) { Write-Host "[WARN]  $m" -ForegroundColor Yellow }
function Err($m)  { Write-Host "[ERROR] $m" -ForegroundColor Red }

Set-Location $ProjectDir

# ----------------------------
# 1) Auto-detect ENV file
# ----------------------------
$envCandidates = @(
    ".env.vercel",
    ".env.production",
    ".env.local",
    ".env"
)

$envFile = $null
foreach ($f in $envCandidates) {
    $full = Join-Path $ProjectDir $f
    if (Test-Path $full) {
        $envFile = $full
        break
    }
}

if ($envFile) {
    Info "Using ENV file: $envFile"

    Get-Content $envFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -eq "" -or $line.StartsWith("#")) { return }

        $parts = $line -split "=", 2
        if ($parts.Count -ne 2) { return }

        $k = $parts[0].Trim()
        $v = $parts[1].Trim()

        # Set only for this process
        [System.Environment]::SetEnvironmentVariable($k, $v, "Process")
    }
} else {
    Warn "No ENV file found (.env, .env.local, .env.production, .env.vercel). Using existing process env only."
}

# ----------------------------
# 2) Resolve pnpm & vercel
# ----------------------------
$pnpmCmd   = "pnpm.cmd"
$vercelCmd = "vercel.cmd"

# If for some reason *.cmd is not on PATH, fall back to bare name
if (-not (Get-Command $pnpmCmd  -ErrorAction SilentlyContinue)) { $pnpmCmd   = "pnpm" }
if (-not (Get-Command $vercelCmd -ErrorAction SilentlyContinue)) { $vercelCmd = "vercel" }

Info "Using pnpm command  : $pnpmCmd"
Info "Using vercel command: $vercelCmd"

# ----------------------------
# 3) Clean stale .next
# ----------------------------
$next = Join-Path $ProjectDir ".next"
if (Test-Path $next) {
    Info "Removing stale .next directory..."
    Remove-Item $next -Recurse -Force -ErrorAction SilentlyContinue
}

# ----------------------------
# 4) Local build (SAFE)
# ----------------------------
Info "Running local build: pnpm run build ..."

$global:LASTEXITCODE = 0
$buildOutput = & $pnpmCmd run build 2>&1
$buildOutput | ForEach-Object { Write-Host $_ }

$buildExit = $LASTEXITCODE
if ($buildExit -ne 0) {
    Err "Local build FAILED with exit code $buildExit."
    exit 1
}

Info "Local build succeeded."

# ----------------------------
# 5) Production deploy
# ----------------------------
Info "Running Vercel deploy: vercel deploy --prod --prebuilt --confirm ..."

$global:LASTEXITCODE = 0
$deployOutput = & $vercelCmd deploy --prod --prebuilt --confirm 2>&1
$deployOutput | ForEach-Object { Write-Host $_ }

$deployExit = $LASTEXITCODE
if ($deployExit -ne 0) {
    Err "Vercel deploy FAILED with exit code $deployExit."
    exit 1
}

Info "Vercel deploy SUCCESSFUL. Phase165e complete."
