<#
  Phase-Prod-HealthCheck.ps1
  Quick production health check for Truvern.

  - Hits key routes on truvern.com
  - Shows HTTP status codes and simple OK/FAIL indicator
#>

$ErrorActionPreference = "Stop"

$projectPath = "C:\Users\MR.NELSON\Downloads\truvern"
Set-Location $projectPath

Write-Host "🌐 Truvern Production Health Check" -ForegroundColor Cyan
Write-Host ""

# Core production base (alias points here)
$base = "https://truvern.com"

$routes = @(
    "/",                        # landing
    "/trust-network",
    "/vendors",
    "/pricing",
    "/contact",

    # vendor + trust extras
    "/trust/embed",
    "/vendor/upload",
    "/vendor/upload-file",

    # dashboards & board reports
    "/dashboard/buyer",
    "/reports/board",
    "/reports/board/preview"
)

function Test-TruvernRoute {
    param(
        [string]$BaseUrl,
        [string]$Path
    )

    $url = "$BaseUrl$Path".Replace("//", "/")
    # fix leading double slash from join
    if ($url -like "https:/truvern.com*") {
        $url = $url -replace "https:/", "https://"
    }

    Write-Host "→ GET $url" -NoNewline

    try {
        $resp = Invoke-WebRequest -Uri $url -Method GET -UseBasicParsing -TimeoutSec 30
        $code = [int]$resp.StatusCode

        if ($code -ge 200 -and $code -lt 300) {
            Write-Host "  [$code OK]" -ForegroundColor Green
        }
        else {
            Write-Host "  [$code WARN]" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "  [FAIL]" -ForegroundColor Red
        Write-Host "   $_" -ForegroundColor DarkRed
    }
}

foreach ($route in $routes) {
    Test-TruvernRoute -BaseUrl $base -Path $route
}

Write-Host ""
Write-Host "✅ Health check complete. Review any WARN/FAIL entries above." -ForegroundColor Cyan
