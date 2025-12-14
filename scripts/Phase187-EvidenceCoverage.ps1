# ==============================================
# Phase187 - Evidence Coverage Snapshot
# Read-only audit of /api/evidence/list on prod
# ==============================================

param()

$projectRoot = "C:\Users\MR.NELSON\Downloads\truvern"
$logDir      = "$projectRoot\scripts\logs\evidence"
$timestamp   = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile     = "$logDir\phase187-evidence-coverage-$timestamp.log"
$summaryFile = "$logDir\phase187-evidence-coverage-latest.log"

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

Write-Log "===== Phase187: Evidence Coverage Snapshot START =====" "Yellow"

# ------------------------------------------------------------------
# Ensure correct working directory (never run from system32)
# ------------------------------------------------------------------
if ((Get-Location).Path -ne $projectRoot) {
    Write-Log "Switching to project root: $projectRoot" "Green"
    Set-Location $projectRoot
}

Write-Log "Current Directory: $(Get-Location)" "Green"

# ------------------------------------------------------------------
# Configure base URL (prod only – via Vercel)
# ------------------------------------------------------------------
$baseUrl = "https://truvern.com"
$listUrl = "$baseUrl/api/evidence/list"

Write-Log "Requesting evidence list from: $listUrl" "Yellow"

try {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $response = Invoke-WebRequest -Uri $listUrl -Method GET -UseBasicParsing -TimeoutSec 20
    $sw.Stop()

    $statusCode = [int]$response.StatusCode
    $elapsed    = $sw.ElapsedMilliseconds

    Write-Log "HTTP $statusCode from /api/evidence/list in ${elapsed}ms" ("Green")

    if ($statusCode -lt 200 -or $statusCode -ge 300) {
        Write-Log "Non-success status from evidence list. Aborting snapshot." "Red"
        Write-Log "===== Phase187: Evidence Coverage Snapshot COMPLETE (ERROR) =====" "Yellow"
        exit 1
    }

    $json = $response.Content | ConvertFrom-Json
}
catch {
    Write-Log "ERROR calling /api/evidence/list: $($_.Exception.Message)" "Red"
    Write-Log "===== Phase187: Evidence Coverage Snapshot COMPLETE (ERROR) =====" "Yellow"
    exit 1
}

# ------------------------------------------------------------------
# Inspect payload shape
# ------------------------------------------------------------------
if (-not $json) {
    Write-Log "Evidence list JSON could not be parsed." "Red"
    Write-Log "===== Phase187: Evidence Coverage Snapshot COMPLETE (ERROR) =====" "Yellow"
    exit 1
}

if (-not $json.evidence) {
    Write-Log "Evidence list payload has no 'evidence' array. Raw JSON:" "Red"
    Write-Log ($response.Content)
    Write-Log "===== Phase187: Evidence Coverage Snapshot COMPLETE (NO DATA) =====" "Yellow"
    exit 0
}

$evidenceItems = $json.evidence
$totalCount    = $evidenceItems.Count

Write-Log "Total evidence records returned: $totalCount" "Green"

# ------------------------------------------------------------------
# Group by vendor and summarize coverage
# ------------------------------------------------------------------
$byVendor = $evidenceItems | Group-Object -Property vendorId

Write-Log "--------------------------------------------" "Yellow"
Write-Log "Per-vendor evidence coverage:" "Yellow"

$coverageRows = @()

foreach ($group in $byVendor) {
    $vendorId    = $group.Name
    $items       = $group.Group
    $count       = $items.Count

    # Try to read vendorName from the first item if present
    $vendorName  = $null
    if ($items[0].PSObject.Properties.Name -contains "vendorName") {
        $vendorName = $items[0].vendorName
    }
    if (-not $vendorName) {
        $vendorName = "Vendor $vendorId"
    }

    $msg = ("VendorId={0} Name='{1}' EvidenceCount={2}" -f $vendorId, $vendorName, $count)
    Write-Log $msg "Gray"

    $coverageRows += [PSCustomObject]@{
        VendorId      = $vendorId
        VendorName    = $vendorName
        EvidenceCount = $count
    }
}

# Also detect vendors that appear in list payload with 0 evidence (unlikely
# with current stub, but future-proofing: if json has a 'vendors' array etc.)
if ($json.PSObject.Properties.Name -contains "vendors") {
    foreach ($v in $json.vendors) {
        $existing = $coverageRows | Where-Object { $_.VendorId -eq $v.id }
        if (-not $existing) {
            $msg = ("VendorId={0} Name='{1}' EvidenceCount=0 (NO EVIDENCE)" -f $v.id, $v.name)
            Write-Log $msg "Red"

            $coverageRows += [PSCustomObject]@{
                VendorId      = $v.id
                VendorName    = $v.name
                EvidenceCount = 0
            }
        }
    }
}

# ------------------------------------------------------------------
# Write a compact summary file
# ------------------------------------------------------------------
"Phase187 Evidence Coverage Snapshot - $(Get-Date)" | Out-File -FilePath $summaryFile -Encoding UTF8
"Source: $listUrl"                                  | Out-File -FilePath $summaryFile -Append -Encoding UTF8
"Total evidence records: $totalCount"               | Out-File -FilePath $summaryFile -Append -Encoding UTF8
""                                                  | Out-File -FilePath $summaryFile -Append -Encoding UTF8
"Per-vendor coverage:"                              | Out-File -FilePath $summaryFile -Append -Encoding UTF8

$coverageRows |
    Sort-Object -Property VendorId |
    ForEach-Object {
        $line = ("- VendorId={0} Name='{1}' EvidenceCount={2}" -f $_.VendorId, $_.VendorName, $_.EvidenceCount)
        $line | Out-File -FilePath $summaryFile -Append -Encoding UTF8
    }

Write-Log "Snapshot directory: $logDir" "Green"
Write-Log "Summary file: $summaryFile" "Green"
Write-Log "===== Phase187: Evidence Coverage Snapshot COMPLETE =====" "Yellow"
