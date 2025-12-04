# ==============================================
# Phase180 - Production Route Health Check
# ==============================================

param()

$projectRoot = "C:\Users\MR.NELSON\Downloads\truvern"
$logDir      = "$projectRoot\scripts\logs"
$timestamp   = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile     = "$logDir\phase180-route-health-$timestamp.log"
$summaryFile = "$logDir\phase180-route-health-latest.log"

if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

function Write-Log {
    param(
        [string]$Message,
        [string]$Color = "Cyan"
    )
    Write-Host $Message -ForegroundColor $Color
    Add-Content -Path $logFile -Value ("[{0}] {1}" -f (Get-Date), $Message)
}

Write-Log "===== Phase180: Production Route Health Check START =====" "Yellow"

# ------------------------------------------------------------------
# Ensure correct working directory (never run from system32)
# ------------------------------------------------------------------
if ((Get-Location).Path -ne $projectRoot) {
    Write-Log "Switching to project root: $projectRoot" "Green"
    Set-Location $projectRoot
}

Write-Log "Current Directory: $(Get-Location)" "Green"

# ------------------------------------------------------------------
# Configure base URLs
# ------------------------------------------------------------------
# Primary production domain
$prodBase = "https://truvern.com"

# Current Vercel deployment base (update if needed)
# You can leave this blank if you only care about the main domain.
$vercelBase = ""   # e.g. "https://truvern-q36ed61xe-nelson-ai-projects.vercel.app"

# Core routes to check on each base
$routes = @(
    "/",                       # home
    "/trust-network",
    "/vendors",
    "/vendors/1",
    "/reports/board",
    "/reports/board/preview",
    "/vendor/upload",
    "/vendor/upload-file",
    "/api/evidence/1",         # sample evidence record
    "/api/evidence/list",      # NEW evidence list API endpoint
    "/api/observe-ping"        # health endpoint
)

# Build list of full URLs to test
$targets = @()

foreach ($route in $routes) {
    if ($prodBase -ne "") {
        $targets += @{ Name = "prod"; Base = $prodBase; Route = $route }
    }
    if ($vercelBase -ne "") {
        $targets += @{ Name = "vercel"; Base = $vercelBase; Route = $route }
    }
}

if ($targets.Count -eq 0) {
    Write-Log "No targets configured. Set prodBase and/or vercelBase." "Red"
    exit 1
}

Write-Log "Checking $($targets.Count) route targets..." "Yellow"

$failed = @()
$ok     = @()

foreach ($t in $targets) {
    $fullUrl = $t.Base.TrimEnd("/") + $t.Route

    Write-Log "Requesting [$($t.Name)] $($t.Route) -> $fullUrl" "Gray"

    $statusCode = $null
    $elapsed    = $null

    try {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $response = Invoke-WebRequest -Uri $fullUrl -Method GET -UseBasicParsing -TimeoutSec 20
        $sw.Stop()

        $statusCode = [int]$response.StatusCode
        $elapsed = $sw.ElapsedMilliseconds

        if ($statusCode -ge 200 -and $statusCode -lt 400) {
            $msg = "[OK] $($t.Name) $($t.Route) - $statusCode (${elapsed}ms)"
            Write-Log $msg "Green"
            $ok += $msg
        }
        else {
            $msg = "[FAIL] $($t.Name) $($t.Route) - $statusCode (${elapsed}ms)"
            Write-Log $msg "Red"
            $failed += $msg
        }
    }
    catch {
        $sw.Stop()
        $elapsed = $sw.ElapsedMilliseconds
        $msg = "[ERROR] $($t.Name) $($t.Route) - Exception after ${elapsed}ms: $($_.Exception.Message)"
        Write-Log $msg "Red"
        $failed += $msg
    }
}

Write-Log "--------------------------------------------" "Yellow"
Write-Log "Summary:" "Yellow"
Write-Log "OK routes:    $($ok.Count)"  "Green"
Write-Log "Failed routes:$($failed.Count)" "Red"

if ($failed.Count -gt 0) {
    Write-Log "Failed route details:" "Red"
    foreach ($f in $failed) {
        Write-Log "  $f" "Red"
    }
}

Write-Log "===== Phase180: Production Route Health Check COMPLETE =====" "Yellow"

# Also save a short summary file for quick inspection
"Phase180 Route Health Check - $(Get-Date)" | Out-File -FilePath $summaryFile -Encoding UTF8
"OK routes:    $($ok.Count)"               | Out-File -FilePath $summaryFile -Append -Encoding UTF8
"Failed routes:$($failed.Count)"           | Out-File -FilePath $summaryFile -Append -Encoding UTF8
""                                          | Out-File -FilePath $summaryFile -Append -Encoding UTF8
"Failures:"                                | Out-File -FilePath $summaryFile -Append -Encoding UTF8
$failed                                    | Out-File -FilePath $summaryFile -Append -Encoding UTF8
