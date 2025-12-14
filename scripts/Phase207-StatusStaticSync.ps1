Write-Host "=== Phase207: Status Static Sync ===" -ForegroundColor Cyan

$Root       = "C:\Users\MR.NELSON\Downloads\truvern"
$SourceDir  = "$Root\public-status"
$PublicDir  = "$Root\public"
$TargetDir  = "$PublicDir\public-status"

# Ensure source exists
if (!(Test-Path $SourceDir)) {
    Write-Host "ERROR: $SourceDir not found. Run Phase206 first." -ForegroundColor Red
    exit 1
}

# Ensure /public and /public/public-status exist
if (!(Test-Path $PublicDir)) {
    New-Item -ItemType Directory -Path $PublicDir | Out-Null
}

if (!(Test-Path $TargetDir)) {
    New-Item -ItemType Directory -Path $TargetDir | Out-Null
}

# Copy badge artifacts into /public/public-status
$filesToCopy = @("badge.json", "badge.svg", "index.json")

foreach ($name in $filesToCopy) {
    $src = Join-Path $SourceDir $name
    $dst = Join-Path $TargetDir $name

    if (Test-Path $src) {
        Copy-Item $src $dst -Force
        Write-Host "Copied $name to $dst"
    } else {
        Write-Host "WARNING: $src not found, skipping" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Static status assets synced to /public/public-status" -ForegroundColor Green
Write-Host "After your next Vercel deploy, these URLs will be live:" -ForegroundColor Cyan
Write-Host "  /public-status/badge.svg"
Write-Host "  /public-status/badge.json"
Write-Host "  /public-status/index.json"

Write-Host "=== Phase207 COMPLETE ===" -ForegroundColor Cyan
