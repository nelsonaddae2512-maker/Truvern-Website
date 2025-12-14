# ==============================================
# Phase188 - Vendor Evidence Panel Health
# Checks /vendors/{id} pages + /api/evidence/list?vendorId={id}
# ==============================================

param()

$projectRoot = "C:\Users\MR.NELSON\Downloads\truvern"
$logDir      = "$projectRoot\scripts\logs"
$timestamp   = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile     = "$logDir\phase188-vendor-evidence-health-$timestamp.log"
$summaryFile = "$logDir\phase188-vendor-evidence-health-latest.log"

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

Write-Log "===== Phase188: Vendor Evidence Panel Health START =====" "Yellow"

# ------------------------------------------------------------------
# Ensure correct working directory (never run from system32)
# ------------------------------------------------------------------
if ((Get-Location).Path -ne $projectRoot) {
    Write-Log "Switching to project root: $projectRoot" "Green"
    Set-Location $projectRoot
}

Write-Log "Current Directory: $(Get-Location)" "Green"

# ------------------------------------------------------------------
# Targets
# ------------------------------------------------------------------
$baseUrl   = "https://truvern.com"

# Adjust this list if you seed more vendors
$vendorIds = @(1, 2, 3, 4)

Write-Log "Checking evidence health for vendor IDs: $($vendorIds -join ', ')" "Yellow"

$ok     = @()
$failed = @()

foreach ($id in $vendorIds) {

    # ---------- Vendor detail page ----------
    $detailRoute = "/vendors/$id"
    $detailUrl   = $baseUrl.TrimEnd("/") + $detailRoute

    Write-Log "Requesting vendor detail [$id] -> $detailUrl" "Gray"

    try {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $resp = Invoke-WebRequest -Uri $detailUrl -Method GET -UseBasicParsing -TimeoutSec 20
        $sw.Stop()

        $status = [int]$resp.StatusCode
        $elapsed = $sw.ElapsedMilliseconds

        if ($status -ge 200 -and $status -lt 400) {
            $msg = "[OK] vendors/$id page - $status (${elapsed}ms)"
            Write-Log $msg "Green"
            $ok += $msg
        } else {
            $msg = "[FAIL] vendors/$id page - $status (${elapsed}ms)"
            Write-Log $msg "Red"
            $failed += $msg
        }
    }
    catch {
        $elapsed = $sw.ElapsedMilliseconds
        $msg = "[ERROR] vendors/$id page - Exception after ${elapsed}ms: $($_.Exception.Message)"
        Write-Log $msg "Red"
        $failed += $msg
    }

    # ---------- Evidence list API ----------
    $apiRoute = "/api/evidence/list?vendorId=$id"
    $apiUrl   = $baseUrl.TrimEnd("/") + $apiRoute

    Write-Log "Requesting evidence list for vendor [$id] -> $apiUrl" "Gray"

    try {
        $sw2 = [System.Diagnostics.Stopwatch]::StartNew()
        $apiResp = Invoke-WebRequest -Uri $apiUrl -Method GET -UseBasicParsing -TimeoutSec 20
        $sw2.Stop()

        $status2 = [int]$apiResp.StatusCode
        $elapsed2 = $sw2.ElapsedMilliseconds

        if ($status2 -lt 200 -or $status2 -ge 400) {
            $msg = "[FAIL] /api/evidence/list?vendorId=$id - $status2 (${elapsed2}ms)"
            Write-Log $msg "Red"
            $failed += $msg
            continue
        }

        # Parse JSON and confirm evidence array
        $json = $null
        try {
            $json = $apiResp.Content | ConvertFrom-Json
        } catch {
            $msg = "[FAIL] /api/evidence/list?vendorId=$id - invalid JSON payload"
            Write-Log $msg "Red"
            $failed += $msg
            continue
        }

        $evidenceArray = $json.evidence
        $count = 0
        if ($evidenceArray) {
            $count = ($evidenceArray | Measure-Object).Count
        }

        if ($null -eq $evidenceArray) {
            $msg = "[FAIL] /api/evidence/list?vendorId=$id - JSON has no 'evidence' array"
            Write-Log $msg "Red"
            $failed += $msg
        } else {
            $msg = "[OK] /api/evidence/list?vendorId=$id - $status2 (${elapsed2}ms), evidence count: $count"
            Write-Log $msg "Green"
            $ok += $msg
        }

    }
    catch {
        $elapsed2 = $sw2.ElapsedMilliseconds
        $msg = "[ERROR] /api/evidence/list?vendorId=$id - Exception after ${elapsed2}ms: $($_.Exception.Message)"
        Write-Log $msg "Red"
        $failed += $msg
    }
}

Write-Log "--------------------------------------------" "Yellow"
Write-Log "Summary:" "Yellow"
Write-Log "OK checks:     $($ok.Count)"  "Green"
Write-Log "Failed checks: $($failed.Count)" "Red"

if ($failed.Count -gt 0) {
    Write-Log "Failed details:" "Red"
    foreach ($f in $failed) {
        Write-Log "  $f" "Red"
    }
}

Write-Log "===== Phase188: Vendor Evidence Panel Health COMPLETE =====" "Yellow"

# Write a short summary file
"Phase188 Vendor Evidence Panel Health - $(Get-Date)" | Out-File -FilePath $summaryFile -Encoding UTF8
"OK checks:     $($ok.Count)"                          | Out-File -FilePath $summaryFile -Append -Encoding UTF8
"Failed checks: $($failed.Count)"                      | Out-File -FilePath $summaryFile -Append -Encoding UTF8
""                                                     | Out-File -FilePath $summaryFile -Append -Encoding UTF8
"Failures:"                                           | Out-File -FilePath $summaryFile -Append -Encoding UTF8
$failed                                               | Out-File -FilePath $summaryFile -Append -Encoding UTF8
