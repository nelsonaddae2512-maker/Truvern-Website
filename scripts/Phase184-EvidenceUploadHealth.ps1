# ==============================================
# Phase184 - Evidence Upload Route Health
# ==============================================

param()

$projectRoot = "C:\Users\MR.NELSON\Downloads\truvern"
$logDir      = "$projectRoot\scripts\logs"
$timestamp   = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile     = "$logDir\phase184-evidence-upload-health-$timestamp.log"
$summaryFile = "$logDir\phase184-evidence-upload-health-latest.log"

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

Write-Log "===== Phase184: Evidence Upload Route Health START =====" "Yellow"

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
$prodBase = "https://truvern.com"
$vercelBase = ""   # e.g. "https://truvern-xxxx-nelson-ai-projects.vercel.app" if you want to include it

# Upload-related routes to check
$routes = @(
    "/vendor/upload",                 # upload landing page
    "/vendor/upload-file?vendorId=1", # upload form wired from evidence page
    "/vendors/1/evidence"             # evidence list for vendor 1
)

# Build full URL targets
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

Write-Log "Checking $($targets.Count) upload-related route targets..." "Yellow"

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
Write-Log "OK upload routes:    $($ok.Count)"  "Green"
Write-Log "Failed upload routes:$($failed.Count)" "Red"

if ($failed.Count -gt 0) {
    Write-Log "Failed upload route details:" "Red"
    foreach ($f in $failed) {
        Write-Log "  $f" "Red"
    }
}

Write-Log "===== Phase184: Evidence Upload Route Health COMPLETE =====" "Yellow"

# Also save a short summary file for quick inspection
"Phase184 Evidence Upload Route Health - $(Get-Date)" | Out-File -FilePath $summaryFile -Encoding UTF8
"OK upload routes:    $($ok.Count)"                  | Out-File -FilePath $summaryFile -Append -Encoding UTF8
"Failed upload routes:$($failed.Count)"              | Out-File -FilePath $summaryFile -Append -Encoding UTF8
""                                                   | Out-File -FilePath $summaryFile -Append -Encoding UTF8
"Failures:"                                          | Out-File -FilePath $summaryFile -Append -Encoding UTF8
$failed                                             | Out-File -FilePath $summaryFile -Append -Encoding UTF8
