$ErrorActionPreference = "Stop"

Write-Host "=== Phase153: Locate Vendor Dossier Page ===" -ForegroundColor Cyan

# 1) Always work from project root
$root = "C:\Users\MR.NELSON\Downloads\truvern"
Set-Location $root
Write-Host "[INFO] Working in $root" -ForegroundColor DarkCyan

# 2) First, try the expected literal path: app/vendors/[id]/page.tsx
$expectedPath = Join-Path $root "app\vendors\[id]\page.tsx"

if (Test-Path -LiteralPath $expectedPath) {
    Write-Host "[INFO] Found vendor dossier at expected path:" -ForegroundColor Green
    Write-Host "       $expectedPath" -ForegroundColor Green
    $vendorPagePath = $expectedPath
} else {
    Write-Host "[WARN] app\vendors\[id]\page.tsx not found. Searching .tsx files..." -ForegroundColor Yellow

    # 3) Search all .tsx files for the text 'Vendor dossier' (from the UI heading)
    $tsxFiles = Get-ChildItem -Path $root -Recurse -File -Include *.tsx

    if (-not $tsxFiles) {
        Write-Host "[ERROR] No .tsx files found under $root. Aborting." -ForegroundColor Red
        exit 1
    }

    $matches = Select-String -Path $tsxFiles.FullName -Pattern "Vendor dossier" -ErrorAction SilentlyContinue

    if (-not $matches) {
        Write-Host "[ERROR] Could not find any .tsx file containing the text 'Vendor dossier'." -ForegroundColor Red
        Write-Host "        Please run 'Get-ChildItem -Recurse -Filter page.tsx' manually to inspect." -ForegroundColor Red
        exit 1
    }

    # Take the first unique path that matched
    $vendorPagePath = ($matches | Select-Object -First 1).Path

    Write-Host "[INFO] Found vendor dossier candidate by content search:" -ForegroundColor Green
    Write-Host "       $vendorPagePath" -ForegroundColor Green
}

# 4) Create a timestamped backup of the vendor page
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupPath = "$vendorPagePath.bak-$timestamp"
Copy-Item -LiteralPath $vendorPagePath -Destination $backupPath

Write-Host "[OK] Backed up vendor dossier page to:" -ForegroundColor Green
Write-Host "     $backupPath" -ForegroundColor Green

# 5) Open the file in Notepad so you can edit it
Write-Host "[STEP] Opening vendor dossier page in Notepad..." -ForegroundColor Cyan
notepad $vendorPagePath

Write-Host "=== Phase153: Locate Vendor Dossier Page complete ===" -ForegroundColor Cyan
