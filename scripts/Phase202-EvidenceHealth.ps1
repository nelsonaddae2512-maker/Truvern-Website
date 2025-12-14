# Phase202-EvidenceHealth.ps1
# Truvern - Evidence and Vendor Health Check (clean, safe version)

param(
    [string]$BaseUrl
)

$ErrorActionPreference = "Stop"

function Log($msg) {
    Write-Host $msg -ForegroundColor Gray
}
function Ok($msg) {
    Write-Host "[OK]   $msg" -ForegroundColor Green
}
function Warn($msg) {
    Write-Host "[WARN] $msg" -ForegroundColor Yellow
}
function Fail($msg) {
    Write-Host "[FAIL] $msg" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Phase202: Evidence and Vendor Health Check ===" -ForegroundColor Cyan
Write-Host ""

# ---------------------------
# Resolve base URL
# ---------------------------

if (-not $BaseUrl -or $BaseUrl -eq "") {
    if ($env:APP_URL -and $env:APP_URL -ne "") {
        $BaseUrl = $env:APP_URL.TrimEnd("/")
        Log ("Using APP_URL from environment: " + $BaseUrl)
    } else {
        $BaseUrl = "https://truvern.com"
        Warn ("APP_URL not set. Defaulting to " + $BaseUrl)
    }
} else {
    $BaseUrl = $BaseUrl.TrimEnd("/")
    Log ("Using base URL from parameter: " + $BaseUrl)
}

# ---------------------------
# Prepare log directory + file
# ---------------------------

$logDir = Join-Path $PSScriptRoot "logs\evidence"
if (!(Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    Log ("Created log directory: " + $logDir)
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$report = Join-Path $logDir ("Phase202-EvidenceHealth-" + $timestamp + ".md")

# ---------------------------
# Helper: HTTP health check
# ---------------------------

function Check-Url {
    param(
        [string]$Name,
        [string]$Url
    )

    $result = "" | Select-Object Name, Url, Ok, Status, DurationMs, Error
    $result.Name = $Name
    $result.Url = $Url
    $result.Ok = $false
    $result.Status = ""
    $result.DurationMs = 0
    $result.Error = ""

    try {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $resp = Invoke-WebRequest -Uri $Url -Method GET -TimeoutSec 20 -ErrorAction Stop
        $sw.Stop()

        $result.Ok = $true
        $result.Status = $resp.StatusCode
        $result.DurationMs = [math]::Round($sw.Elapsed.TotalMilliseconds)

        Ok ($Name + " returned " + $resp.StatusCode + " in " + $result.DurationMs + " ms")
    }
    catch {
        $result.Ok = $false
        $result.Error = $_.Exception.Message
        Fail ($Name + " failed: " + $result.Error)
    }

    return $result
}

# ---------------------------
# 1) Endpoint checks
# ---------------------------

$checks = @()
$checks += Check-Url "Root page"        ($BaseUrl + "/")
$checks += Check-Url "Board page"       ($BaseUrl + "/reports/board")
$checks += Check-Url "Vendors page"     ($BaseUrl + "/vendors")
$checks += Check-Url "Trust network"    ($BaseUrl + "/trust-network")
$checks += Check-Url "Evidence API"     ($BaseUrl + "/api/evidence/list")
$checks += Check-Url "Vendors API"      ($BaseUrl + "/api/vendors")

# ---------------------------
# 2) Evidence JSON summary
# ---------------------------

$evSummary = "" | Select-Object Count, Vendors, SampleItem, Error
$evSummary.Count = 0
$evSummary.Vendors = 0
$evSummary.SampleItem = ""
$evSummary.Error = ""

try {
    Log "Requesting evidence JSON..."
    $resp = Invoke-WebRequest -Uri ($BaseUrl + "/api/evidence/list") -Method GET -TimeoutSec 20 -ErrorAction Stop
    $json = $resp.Content | ConvertFrom-Json

    if ($json.PSObject.Properties.Name -contains "items") {
        $list = @($json.items)
    } else {
        $list = @($json)
    }

    $list = $list | Where-Object { $_ -ne $null }

    $evSummary.Count = $list.Count

    if ($list.Count -gt 0) {
        $groups = $list | Where-Object { $_.vendorId } | Group-Object -Property vendorId
        $evSummary.Vendors = $groups.Count

        # Sample item as compact JSON for the report
        $evSummary.SampleItem = ($list[0] | ConvertTo-Json -Compress)
    }

    Ok ("Evidence items: " + $evSummary.Count + " across " + $evSummary.Vendors + " vendors.")
}
catch {
    $evSummary.Error = $_.Exception.Message
    Warn ("Evidence JSON parse failed: " + $evSummary.Error)
}

# ---------------------------
# 3) Build markdown report
# ---------------------------

$lines = @()

$lines += "# Phase202 Evidence and Vendor Health Report"
$lines += ""
$lines += ("Generated: " + (Get-Date -Format u))
$lines += ("Base URL: " + $BaseUrl)
$lines += ""
$lines += "## Endpoint Status"
$lines += ""
$lines += "| Name | URL | OK | Status | Duration (ms) | Error |"
$lines += "|------|-----|----|--------|---------------|--------|"

foreach ($c in $checks) {
    $okFlag = if ($c.Ok) { "YES" } else { "NO" }
    $statusText = if ($c.Status) { [string]$c.Status } else { "" }
    $errText = if ($c.Error) { $c.Error -replace "\|","/" } else { "" }

    $line = "| " + $c.Name + " | " + $c.Url + " | " + $okFlag + " | " +
            $statusText + " | " + $c.DurationMs + " | " + $errText + " |"

    $lines += $line
}

$lines += ""
$lines += "## Evidence Summary"
$lines += ("Total items: " + $evSummary.Count)
$lines += ("Vendors with evidence: " + $evSummary.Vendors)

if ($evSummary.SampleItem -ne "") {
    $lines += ("Sample item: " + $evSummary.SampleItem)
}
if ($evSummary.Error -ne "") {
    $lines += ("Evidence JSON error: " + $evSummary.Error)
}

# Write file
$body = $lines -join "`r`n"
Set-Content -Path $report -Value $body -Encoding UTF8

Write-Host ""
Write-Host ("Report saved to: " + $report) -ForegroundColor Yellow
Write-Host "===== Phase202 COMPLETE =====" -ForegroundColor Cyan
Write-Host ""
