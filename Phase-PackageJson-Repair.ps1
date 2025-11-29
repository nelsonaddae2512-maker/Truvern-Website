# Phase-PackageJson-Repair.ps1
# Restores a valid package.json from backup if the current one is broken.

$ErrorActionPreference = "Stop"

Write-Host "== Truvern package.json repair ==" -ForegroundColor Cyan
Set-Location "C:\Users\MR.NELSON\Downloads\truvern"

function Test-PackageJson {
    param(
        [string]$Path
    )
    if (-not (Test-Path $Path)) {
        return $null
    }

    try {
        $raw = Get-Content $Path -Raw -ErrorAction Stop
        $obj = $raw | ConvertFrom-Json -ErrorAction Stop
        if ($obj -and $obj.name) {
            return @{
                Path = $Path
                Raw  = $raw
            }
        }
    } catch {
        return $null
    }
}

Write-Host "Looking for a valid backup package.json..." -ForegroundColor Yellow

# Try the two backup files first
$candidates = @(
    "package.backup.json",
    "package.bak.json"
)

$validBackup = $null
foreach ($c in $candidates) {
    $result = Test-PackageJson -Path $c
    if ($result) {
        $validBackup = $result
        break
    }
}

if (-not $validBackup) {
    Write-Host "No valid backup package.json found. Aborting." -ForegroundColor Red
    exit 1
}

Write-Host "Found valid backup: $($validBackup.Path)" -ForegroundColor Green

# Backup the current (broken) package.json just in case
if (Test-Path "package.json") {
    $timestamp = Get-Date -Format "yyyyMMddHHmmss"
    $backupPath = "package.broken.$timestamp.json"
    Copy-Item "package.json" $backupPath -Force
    Write-Host "Current package.json backed up as $backupPath" -ForegroundColor Yellow
}

# Write the good JSON back to package.json
$validBackup.Raw | Set-Content -Path "package.json" -Encoding UTF8
Write-Host "package.json restored from $($validBackup.Path)" -ForegroundColor Green

Write-Host "You can quickly inspect it with:  notepad package.json" -ForegroundColor Cyan
Write-Host "Now run: npm install   and then: npm run build" -ForegroundColor Cyan
