param(
    [string]$ProjectDir = "C:\Users\MR.NELSON\Downloads\truvern"
)

# ============================================
# Phase165f: FINAL DEPLOY (ignore bad Vercel IDs)
# ============================================

$ErrorActionPreference = "Continue"

function Info($m) { Write-Host "[INFO]  $m" }
function Warn($m) { Write-Host "[WARN]  $m" -ForegroundColor Yellow }
function Err($m)  { Write-Host "[ERROR] $m" -ForegroundColor Red }

Set-Location $ProjectDir

# ----------------------------
# 1) Load ENV but SKIP Vercel IDs
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

$skipKeys = @("VERCEL_PROJECT_ID","VERCEL_ORG_ID","VERCEL_TOKEN")

if ($envFile) {
    Info "Using ENV file: $envFile"

    Get-Content $envFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -eq "" -or $line.StartsWith("#")) { return }

        $parts = $line -split "=", 2
        if ($parts.Count -ne 2) { return }

        $k = $parts[0].Trim()
        $v = $parts[1].Trim()

        if ($skipKeys -contains $k) {
            Warn "Skipping $k from env (will use .vercel\project.json instead)."
            return
        }

        [System.Environment]::SetEnvironmentVariable($k, $v, "Process")
    }
} else {
    Warn "No ENV file (.env / .env.local / .env.production / .env.vercel) found."
}

# Also clear any existing Vercel IDs in this process just in case
[System.Environment]::SetEnvironmentVariable("VERCEL_PROJECT_ID", $null, "Process")
[System.Environment]::SetEnvironmentVariable("VERCEL_ORG_ID", $null, "Process")
[System.Environment]::SetEnvironmentVariable("VERCEL_TOKEN", $null, "Process")

Info "Vercel project will be resolved from .vercel\project.json (linked project)."

# ----------------------------
# 2) Resolve pnpm & vercel
# ----------------------------
$pnpmCmd   = "pnpm.cmd"
$vercelCmd = "vercel.cmd"

if (-not (Get-Command $pnpmCmd  -ErrorAction SilentlyContinue)) { $pnpmCmd   = "pnpm" }
if (-not (Get-Command $vercelCmd -ErrorAction SilentlyContinue)) { $vercelCmd = "vercel" }

Info "Using pnpm command  : $pnpmCmd"
Info "Using vercel command: $vercelCmd"

# ----------------------------
# 3) Clean stale .next and .vercel/output
# ----------------------------
$nextDir   = Join-Path $ProjectDir ".next"
$outputDir = Join-Path $ProjectDir ".vercel\output"

if (Test-Path $nextDir) {
    Info "Removing stale .next directory..."
    Remove-Item $nextDir -Recurse -Force -ErrorAction SilentlyContinue
}

if (Test-Path $outputDir) {
    Info "Removing stale .vercel\output directory..."
    Remove-Item $outputDir -Recurse -Force -ErrorAction SilentlyContinue
}

# ----------------------------
# 4) Local Next.js build
# ----------------------------
Info "Running local Next.js build: pnpm run build ..."

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
# 5) Vercel build (prebuilt output)
# ----------------------------
Info "Running Vercel build --prebuilt ..."

$global:LASTEXITCODE = 0
$vbOutput = & $vercelCmd build --prebuilt 2>&1
$vbOutput | ForEach-Object { Write-Host $_ }

$vbExit = $LASTEXITCODE
if ($vbExit -ne 0) {
    Err "Vercel build FAILED with exit code $vbExit."
    exit 1
}

Info "Vercel build succeeded; prebuilt output ready."

# ----------------------------
# 6) Production deploy
# ----------------------------
Info "Running Vercel deploy --prod --prebuilt --yes ..."

$global:LASTEXITCODE = 0
$deployOutput = & $vercelCmd deploy --prod --prebuilt --yes 2>&1
$deployOutput | ForEach-Object { Write-Host $_ }

$deployExit = $LASTEXITCODE
if ($deployExit -ne 0) {
    Err "Vercel deploy FAILED with exit code $deployExit."
    exit 1
}

Info "Vercel deploy SUCCESSFUL. Phase165f complete."
