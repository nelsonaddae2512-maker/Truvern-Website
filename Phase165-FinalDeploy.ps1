# ================================
# Phase165: Final Deploy Script
# Compatible with Windows PowerShell 5.1
# ================================

Write-Host ""
Write-Host "=== Phase165: Final Deployment Start ===" -ForegroundColor Cyan
Write-Host ""

# -------------------------------
# Helpers
# -------------------------------

function Log {
    param([string]$msg)
    Write-Host "[INFO] $msg"
}

$root = Get-Location

# -------------------------------
# Load .env (PowerShell 5 safe)
# -------------------------------

$envFile = Join-Path $root ".env"

Log "Loading environment variables from .env ..."

if (Test-Path $envFile) {
    $lines = Get-Content $envFile

    foreach ($line in $lines) {
        if ($line -match "^\s*#") { continue }
        if ($line.Trim() -eq "") { continue }

        if ($line -match "^(?<k>[^=]+)=(?<v>.*)$") {
            $key = $matches['k'].Trim()
            $val = $matches['v']

            # Trim quotes if needed
            if ($val.StartsWith('"') -and $val.EndsWith('"')) {
                $val = $val.Trim('"')
            } elseif ($val.StartsWith("'") -and $val.EndsWith("'")) {
                $val = $val.Trim("'")
            }

            # Safe setter
            [System.Environment]::SetEnvironmentVariable($key, $val, "Process")
        }
    }
} else {
    Write-Host "WARNING: .env not found at $envFile" -ForegroundColor Yellow
}

# -------------------------------
# Validate critical variables
# -------------------------------

$required = @(
    "VERCEL_TOKEN",
    "VERCEL_ORG_ID",
    "VERCEL_PROJECT_ID"
)

$missing = @()

foreach ($k in $required) {
    $v = [System.Environment]::GetEnvironmentVariable($k, "Process")
    if (-not $v -or $v -eq "") {
        $missing += $k
    }
}

if ($missing.Count -gt 0) {
    Write-Host "Missing required environment variables:" -ForegroundColor Red
    foreach ($m in $missing) {
        Write-Host "- $m" -ForegroundColor Red
    }
    Write-Host "`nFix the .env file before deploying." -ForegroundColor Red
    exit 1
}

# -------------------------------
# Run Build
# -------------------------------

Log "Running production build..."
$build = npm run build 2>&1

Write-Host $build

# -------------------------------
# Run Prebuilt Deploy
# -------------------------------

Log "Running Vercel deploy (prebuilt)..."

$deployCmd = "vercel deploy --prebuilt --prod --token $($env:VERCEL_TOKEN) --yes"

$deployOutput = Invoke-Expression $deployCmd 2>&1
Write-Host $deployOutput

Write-Host ""
Write-Host "Phase165 complete." -ForegroundColor Green
Write-Host ""
