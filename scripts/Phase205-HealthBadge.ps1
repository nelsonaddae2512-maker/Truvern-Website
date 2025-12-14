Import-Module "$PSScriptRoot\integrity\HashEngine.psm1" -Force

$Root      = "C:\Users\MR.NELSON\Downloads\truvern"
$LogDir    = "$Root\scripts\logs\badges"
$Pointer   = "$Root\scripts\logs\integrity\master-seal-latest.json"

if (!(Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir | Out-Null
}

Write-Host "=== Phase205: Health Badge Generator ===" -ForegroundColor Cyan

# Load pointer
if (!(Test-Path $Pointer)) {
    Write-Host "ERROR: master-seal-latest.json not found." -ForegroundColor Red
    exit 1
}

$ptr = Get-Content $Pointer | ConvertFrom-Json
$expected = $ptr.masterSeal

Write-Host "Expected seal: $expected" -ForegroundColor Yellow

# Compute current seal
$map = Compute-FileHashMap -Root $Root
$computed = Compute-Seal -Map $map

Write-Host "Computed seal: $computed" -ForegroundColor Yellow

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

# Determine status
if ($computed -eq $expected) {
    $status = "OK"
    Write-Host "STATUS: OK - Integrity verified" -ForegroundColor Green
} else {
    $status = "MISMATCH"
    Write-Host "STATUS: MISMATCH - Seal mismatch detected" -ForegroundColor Red
}

# Pick badge color (PowerShell does NOT support '? :' so we use if/else)
if ($status -eq "OK") {
    $color = "#4caf50"
} else {
    $color = "#e53935"
}

# -------------------------------
# Write JSON badge
# -------------------------------
$jsonBadge = @{
    status      = $status
    expected    = $expected
    computed    = $computed
    timestamp   = $timestamp
} | ConvertTo-Json -Depth 5

$jsonFile = "$LogDir\badge-$timestamp.json"
$jsonBadge | Out-File $jsonFile -Encoding ascii

Write-Host "Wrote JSON badge: $jsonFile"

# -------------------------------
# Write SVG badge
# -------------------------------
$svg = @"
<svg xmlns="http://www.w3.org/2000/svg" width="170" height="30">
  <rect width="170" height="30" fill="#444"/>
  <rect x="80" width="90" height="30" fill="$color"/>
  <text x="10" y="20" fill="#ffffff" font-family="Arial" font-size="14">Integrity</text>
  <text x="90" y="20" fill="#ffffff" font-family="Arial" font-size="14">$status</text>
</svg>
"@

$svgFile = "$LogDir\badge-$timestamp.svg"
$svg | Out-File $svgFile -Encoding ascii

Write-Host "Wrote SVG badge: $svgFile"

Write-Host "=== Phase205 COMPLETE ===" -ForegroundColor Cyan
