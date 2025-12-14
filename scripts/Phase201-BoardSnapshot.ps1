# Phase201-BoardSnapshot.ps1
# Pulls the live board report CSV from the Truvern app and saves it under scripts\logs\board.

param(
    # Optional override, e.g. https://truvern-ekz123-nelson-ai-projects.vercel.app
    [string]$BaseUrl
)

$ErrorActionPreference = "Stop"

function Write-PhaseHeader {
    param([string]$Text)
    Write-Host ""
    Write-Host "=== $Text ===" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Info {
    param([string]$Text)
    Write-Host "[INFO] $Text" -ForegroundColor Gray
}

function Write-Ok {
    param([string]$Text)
    Write-Host "[OK]   $Text" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Text)
    Write-Host "[WARN] $Text" -ForegroundColor Yellow
}

function Write-Fail {
    param([string]$Text)
    Write-Host "[FAIL] $Text" -ForegroundColor Red
}

try {
    Write-PhaseHeader "Phase201: Board Snapshot Export"

    # Resolve project root (scripts folder is one level below)
    $scriptsRoot = $PSScriptRoot
    $projectRoot = Split-Path $scriptsRoot -Parent
    Set-Location $projectRoot

    Write-Info "Project root: $projectRoot"

    # Resolve base URL
    if (-not $BaseUrl -or [string]::IsNullOrWhiteSpace($BaseUrl)) {
        if ($env:APP_URL -and -not [string]::IsNullOrWhiteSpace($env:APP_URL)) {
            $BaseUrl = $env:APP_URL.TrimEnd("/")
            Write-Info "Using APP_URL from environment: $BaseUrl"
        }
        else {
            $BaseUrl = "https://truvern.com"
            Write-Warn "APP_URL not set in environment. Defaulting to $BaseUrl"
        }
    }
    else {
        $BaseUrl = $BaseUrl.TrimEnd("/")
        Write-Info "Using base URL from parameter: $BaseUrl"
    }

    # Prepare log directory
    $logDir = Join-Path $scriptsRoot "logs\board"
    if (-not (Test-Path $logDir)) {
        Write-Info "Creating log directory: $logDir"
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $csvPath = Join-Path $logDir "board-report-$timestamp.csv"

    # URLs
    $csvUrl = "$BaseUrl/api/reports/board/csv"
    $healthUrl = "$BaseUrl/reports/board"

    Write-Info "Health check URL: $healthUrl"
    Write-Info "CSV URL:          $csvUrl"
    Write-Info "Output file:      $csvPath"

    # 1) Quick health check on the board page
    Write-Info "Checking board page..."
    try {
        $healthResponse = Invoke-WebRequest -Uri $healthUrl -Method GET -TimeoutSec 20 -ErrorAction Stop
        if ($healthResponse.StatusCode -ge 200 -and $healthResponse.StatusCode -lt 300) {
            Write-Ok "Board page reachable (status $($healthResponse.StatusCode))"
        }
        else {
            Write-Warn "Board page returned status $($healthResponse.StatusCode). Continuing anyway."
        }
    }
    catch {
        Write-Warn "Board page health check failed: $($_.Exception.Message)"
    }

    # 2) Download CSV
    Write-Info "Requesting board CSV..."
    try {
        Invoke-WebRequest -Uri $csvUrl -Method GET -TimeoutSec 30 -OutFile $csvPath -ErrorAction Stop
        Write-Ok "Board CSV saved to: $csvPath"
    }
    catch {
        Write-Fail "Failed to download board CSV: $($_.Exception.Message)"
        throw
    }

    Write-Host ""
    Write-Host "===== Phase201 COMPLETE =====" -ForegroundColor Yellow
    Write-Host ""
}
catch {
    Write-Host ""
    Write-Fail "Phase201 failed: $($_.Exception.Message)"
    Write-Host ""
    exit 1
}
