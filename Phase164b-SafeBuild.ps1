# Phase164b-SafeBuild.ps1
# SAFE BUILD + lambda route scan (no hard failures, no host exit)

# ------------------------------
# Basic setup
# ------------------------------
$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'SilentlyContinue'

$root = Get-Location

$logsDir = Join-Path $root 'logs'
if (-not (Test-Path $logsDir)) {
    New-Item -ItemType Directory -Path $logsDir | Out-Null
}

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$logFile   = Join-Path $logsDir "Phase164b-SafeBuild-$timestamp.log"

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = 'INFO'
    )
    $line = "[{0}] [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    $line | Tee-Object -FilePath $logFile -Append
}

Write-Log "=== Phase164b: SAFE BUILD START ==="

# ------------------------------
# Sanity checks
# ------------------------------
if (-not (Test-Path (Join-Path $root 'package.json'))) {
    Write-Log "package.json not found in $root. Are you in the project root?" 'ERROR'
    Write-Host "Phase164b aborted: package.json not found in current folder." -ForegroundColor Red
    Write-Host "Current folder: $root"
    return
}

# ------------------------------
# Clean old prebuilt output
# ------------------------------
$prebuiltDir = Join-Path $root '.vercel\output'
if (Test-Path $prebuiltDir) {
    Write-Log "Removing existing prebuilt output at $prebuiltDir"
    try {
        Remove-Item $prebuiltDir -Recurse -Force -ErrorAction Stop
    } catch {
        Write-Log "Failed to remove $prebuiltDir : $($_.Exception.Message)" 'WARN'
    }
} else {
    Write-Log "No .vercel/output directory found; nothing to clean."
}

# ------------------------------
# Run pnpm build (SAFE wrapper)
# ------------------------------
Write-Log "Running 'pnpm run build'..."
$buildOutput   = @()
$buildExitCode = 0

try {
    $buildOutput = & pnpm run build 2>&1
    $buildExitCode = $LASTEXITCODE
} catch {
    Write-Log "Exception while running pnpm build: $($_.Exception.Message)" 'ERROR'
}

if ($buildOutput) {
    $buildOutput | Tee-Object -FilePath $logFile -Append | Out-Null
}

if ($buildExitCode -ne 0) {
    Write-Log "pnpm build exited with code $buildExitCode (continuing anyway for diagnostics)" 'WARN'
} else {
    Write-Log "pnpm build completed successfully (exit code 0)."
}

# ------------------------------
# Optional: vercel build --prebuilt
# ------------------------------
$vercelOutput   = @()
$vercelExitCode = $null

if (Get-Command vercel -ErrorAction SilentlyContinue) {
    Write-Log "Running 'vercel build --prebuilt' for lambda diagnostics..."
    try {
        $vercelOutput = & vercel build --prebuilt 2>&1
        $vercelExitCode = $LASTEXITCODE
    } catch {
        Write-Log "Exception while running vercel build: $($_.Exception.Message)" 'WARN'
    }

    if ($vercelOutput) {
        $vercelOutput | Tee-Object -FilePath $logFile -Append | Out-Null
    }

    if ($vercelExitCode -ne 0) {
        Write-Log "vercel build exited with code $vercelExitCode (this is expected if some lambdas are missing)" 'WARN'
    } else {
        Write-Log "vercel build completed successfully (exit code 0)."
    }
} else {
    Write-Log "Vercel CLI not found on PATH; skipping 'vercel build --prebuilt' step." 'WARN'
}

# ------------------------------
# Scan combined output for lambda errors
# ------------------------------
Write-Log "Scanning build + vercel output for 'Unable to find lambda for route:' messages..."

$combined = @()
if ($buildOutput)  { $combined += $buildOutput }
if ($vercelOutput) { $combined += $vercelOutput }

$errors = $combined | Select-String -Pattern 'Unable to find lambda for route:'

Write-Host ""
if ($errors) {
    Write-Host "Detected lambda route issues:" -ForegroundColor Yellow
    $errors | ForEach-Object { Write-Host $_.Line -ForegroundColor Yellow }
    Write-Log "Detected $($errors.Count) lambda route error line(s)." 'WARN'
} else {
    Write-Host "No 'Unable to find lambda for route:' errors found in this run." -ForegroundColor Green
    Write-Log "No lambda route errors found." 'INFO'
}

Write-Host ""
Write-Host "Phase164b complete. Log saved: $logFile" -ForegroundColor Green
Write-Log "Phase164b complete. SAFE BUILD script finished." 'INFO'
