# =========================
# Phase80-AutoMirror-Fix.ps1
# =========================
param([switch]$NoDeploy)

$ErrorActionPreference = 'Stop'

# ---- Safety: always run from the script's folder (never from system32) ----
Set-Location -Path $PSScriptRoot

Write-Host "`n=== Phase 80: Vercel CLI path fix & deploy ===`n"

function Get-VercelPath {
    # 1) Try normal command discovery
    $cmd = Get-Command vercel -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    # 2) Try the common global npm bin on Windows
    $globalBin = Join-Path $env:APPDATA 'npm'
    $candidate = Join-Path $globalBin 'vercel.cmd'
    if (Test-Path $candidate) { return $candidate }

    # 3) Try npm prefix
    try {
        $prefix = (npm prefix -g).Trim()
        if ($prefix) {
            $candidate2 = Join-Path (Join-Path $prefix 'vercel.cmd') ''
            if (Test-Path $candidate2) { return $candidate2 }
            $candidate3 = Join-Path (Join-Path $prefix 'bin') 'vercel.cmd'
            if (Test-Path $candidate3) { return $candidate3 }
        }
    } catch {}

    return $null
}

# Ensure npm global bin is on PATH for this session
$npmGlobal = Join-Path $env:APPDATA 'npm'
if ($env:PATH -notlike "*$npmGlobal*") {
    $env:PATH = "$npmGlobal;$env:PATH"
}

# Install or confirm Vercel CLI
$vercelPath = Get-VercelPath
if (-not $vercelPath) {
    Write-Host "Installing Vercel CLI globally (npm i -g vercel) ..."
    npm install -g vercel | Out-Null
    # refresh PATH again after install
    if ($env:PATH -notlike "*$npmGlobal*") {
        $env:PATH = "$npmGlobal;$env:PATH"
    }
    $vercelPath = Get-VercelPath
}

if ($vercelPath) {
    Write-Host "✅ Vercel CLI found at: $vercelPath"
    $V = $vercelPath
} else {
    Write-Warning "Vercel CLI still not on disk. Will fall back to 'npx vercel'."
    $V = "npx vercel"
}

# ---- Pull env for production (keeps your .vercel/.env.production.local fresh) ----
Write-Host "`n=== vercel pull (production) ==="
& $V pull --environment=production --yes

# ---- Deploy (unless explicitly skipped) ----
if (-not $NoDeploy) {
    Write-Host "`n=== vercel deploy --prod ==="
    & $V deploy --prod --yes
} else {
    Write-Host "`n(NoDeploy) Skipping deploy step."
}

Write-Host "`nDone."
