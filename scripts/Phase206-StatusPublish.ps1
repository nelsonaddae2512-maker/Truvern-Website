Import-Module "$PSScriptRoot\integrity\HashEngine.psm1" -Force

$Root      = "C:\Users\MR.NELSON\Downloads\truvern"
$SourceDir = "$Root\scripts\logs\badges"
$OutDir    = "$Root\public-status"

Write-Host "=== Phase206: Public Status Publish ===" -ForegroundColor Cyan

# Ensure output directory exists
if (!(Test-Path $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir | Out-Null
}

# Find latest JSON + SVG badge from Phase205
$latestJson = Get-ChildItem $SourceDir -Filter "badge-*.json" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$latestSvg  = Get-ChildItem $SourceDir -Filter "badge-*.svg"  | Sort-Object LastWriteTime -Descending | Select-Object -First 1

if (-not $latestJson -or -not $latestSvg) {
    Write-Host "ERROR: No badge files found. Run Phase205 first." -ForegroundColor Red
    exit 1
}

Write-Host "Publishing latest badge files..." -ForegroundColor Yellow
Write-Host "JSON: $($latestJson.FullName)"
Write-Host "SVG : $($latestSvg.FullName)"

# Copy to public-status folder
Copy-Item $latestJson.FullName "$OutDir\badge.json" -Force
Copy-Item $latestSvg.FullName  "$OutDir\badge.svg"  -Force

# Write index.json for quick API response
$badgeInfo = @{
    status   = "OK"
    updated  = (Get-Date -Format "yyyyMMdd_HHmmss")
    json     = "/public-status/badge.json"
    svg      = "/public-status/badge.svg"
}

$indexFile = "$OutDir\index.json"
$badgeInfo | ConvertTo-Json -Depth 5 | Out-File $indexFile -Encoding ascii

Write-Host "Wrote public badge JSON to: $indexFile"
Write-Host "Wrote badge.json and badge.svg to /public-status" -ForegroundColor Green

Write-Host "=== Phase206 COMPLETE: Public status artifacts ready for deploy ===" -ForegroundColor Cyan
