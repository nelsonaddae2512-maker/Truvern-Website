param(
    [string]$ProjectDir = "C:\Users\MR.NELSON\Downloads\truvern"
)

# ============================================
# Phase165d: FINAL DEPLOY (AUTO ENV DETECT)
# ============================================

$ErrorActionPreference = "Stop"

function Info($m) { Write-Host "[INFO] $m" }
function Warn($m) { Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Err($m)  { Write-Host "[ERROR] $m" -ForegroundColor Red }

Set-Location $ProjectDir

# Select best ENV file automatically
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

        [System.Environment]::SetEnvironmentVariable($k, $v, "Process")
    }

} else {
    Warn "No ENV file found (.env or .env.local or .env.vercel)"
}

# ==============================
# CLEAN OLD .next
# ==============================
$next = Join-Path $ProjectDir ".next"
if (Test-Path $next) {
    Info "Removing stale .next..."
    Remove-Item $next -Recurse -Force -ErrorAction SilentlyContinue
}

# ==============================
# LOCAL BUILD
# ==============================
Info "Running local build: pnpm run build..."

$buildOut = & pnpm run build 2>&1
$buildOut | ForEach-Object { Write-Host $_ }

if ($LASTEXITCODE -ne 0) {
    Err "Local build FAILED."
    exit 1
}

Info "Local BUILD succeeded."

# ==============================
# DEPLOY TO PRODUCTION
# ==============================
Info "Running Vercel production deploy..."

$deployOut = & vercel deploy --prod --confirm 2>&1
$deployOut | ForEach-Object { Write-Host $_ }

if ($LASTEXITCODE -ne 0) {
    Err "Vercel deploy FAILED."
    exit 1
}

Info "Vercel deploy SUCCESSFUL!"
