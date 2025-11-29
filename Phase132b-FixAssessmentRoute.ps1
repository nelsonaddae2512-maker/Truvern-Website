<# 
    Phase132b-FixAssessmentRoute.ps1
    -----------------------------------------
    - Searches the project source (NOT .next or node_modules)
    - Fixes any accidental "results_disabled_..." path
    - Backs up each changed file as *.bak-phase132b
#>

param(
    [string]$ProjectDir = $PSScriptRoot
)

$ErrorActionPreference = "Stop"

Write-Host "=== Phase132b: Fix Assessment Route ===" -ForegroundColor Magenta

# Normalize working directory
try {
    if (-not $ProjectDir -or $ProjectDir -eq "") {
        $ProjectDir = $PSScriptRoot
    }
    $projectPath = Resolve-Path $ProjectDir
} catch {
    Write-Host "[ERROR] Unable to resolve ProjectDir." -ForegroundColor Red
    exit 1
}

# Avoid System32
if ($PWD.Path -like "*System32*") {
    Set-Location $projectPath
} else {
    Set-Location $projectPath
}

Write-Host "[INFO] Working in: $((Get-Location).Path)" -ForegroundColor Cyan

# Files to scan
$searchFiles = Get-ChildItem -Recurse -File -Include *.js,*.ts,*.tsx,*.jsx,*.mjs,*.mts,*.json `
    | Where-Object {
        $_.FullName -notmatch '\\node_modules\\' -and `
        $_.FullName -notmatch '\\.next\\'
    }

$pattern = "results_disabled_[0-9\-]+"
$filesChanged = @()

foreach ($file in $searchFiles) {
    try {
        $content = Get-Content $file.FullName | Out-String
    } catch {
        continue
    }

    if ($content -match $pattern) {
        Write-Host "[HIT] $($file.FullName)" -ForegroundColor Yellow

        # Backup
        $backupPath = "$($file.FullName).bak-phase132b"
        Copy-Item $file.FullName $backupPath -Force

        # Fix
        $new = $content -replace $pattern, "results"
        Set-Content -Path $file.FullName -Value $new -Encoding UTF8

        $filesChanged += $file.FullName
    }
}

Write-Host ""
if ($filesChanged.Count -gt 0) {
    Write-Host "Phase132b complete. Patched files:" -ForegroundColor Green
    $filesChanged | ForEach-Object { Write-Host " - $_" -ForegroundColor Green }
    Write-Host "Backups created as *.bak-phase132b" -ForegroundColor Yellow
} else {
    Write-Host "Phase132b: No files contained results_disabled_ patterns." -ForegroundColor Cyan
}

exit 0
