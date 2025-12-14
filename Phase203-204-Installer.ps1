# Phase203-204-Installer.ps1
# Creates Phase203-MasterSeal-FIX.ps1 + Phase204-MasterSealVerify.ps1

Write-Host "=== Truvern Integrity Installer (Phase203 + Phase204) ===" -ForegroundColor Cyan

# Ensure we are in a project-looking directory
$root = Get-Location
if (-not (Test-Path (Join-Path $root "package.json"))) {
    Write-Warning "No package.json found in $root. Make sure you are in the truvern project root."
}

# Directories
$scriptsDir   = Join-Path $root "scripts"
$logDir       = Join-Path $scriptsDir "logs\integrity"

New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null
New-Item -ItemType Directory -Path $logDir -Force | Out-Null

# --- Phase203 script content ---
$phase203Path = Join-Path $scriptsDir "Phase203-MasterSeal-FIX.ps1"
$phase203 = @'
param()

Write-Host "=== Phase203: Master Seal (FIX) ===" -ForegroundColor Cyan

# Project root = parent of scripts folder
$ProjectRoot = Split-Path $PSScriptRoot -Parent
$LogDir      = Join-Path $PSScriptRoot "logs\\integrity"
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null

$timestamp   = Get-Date -Format "yyyyMMdd_HHmmss"
$outJson     = Join-Path $LogDir "Phase203-MasterSeal-$timestamp.json"
$latestJson  = Join-Path $LogDir "master-seal-latest.json"

function Should-SkipFile([string]$fullPath, [string]$root) {
    $rel = $fullPath.Substring($root.Length).TrimStart('\','/')
    if ($rel -like "node_modules/*") { return $true }
    if ($rel -like ".git/*")         { return $true }
    if ($rel -like ".next/*")        { return $true }
    if ($rel -like "scripts/logs/*") { return $true }
    return $false
}

Write-Host "Project root: $ProjectRoot" -ForegroundColor Gray
Write-Host "Collecting files..." -ForegroundColor Gray

$entries = @()
$included = 0
$skipped  = 0

Get-ChildItem -Path $ProjectRoot -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
    $file = $_
    if (Should-SkipFile $file.FullName $ProjectRoot) {
        $skipped++
        return
    }

    try {
        $hash = Get-FileHash -Path $file.FullName -Algorithm SHA256
        $relative = $file.FullName.Substring($ProjectRoot.Length).TrimStart('\','/')
        $entries += [pscustomobject]@{
            path = $relative
            hash = $hash.Hash.ToLower()
        }
        $included++
    }
    catch {
        Write-Warning "Failed to hash: $($file.FullName). Skipping."
        $skipped++
    }
}

Write-Host "Included files: $included" -ForegroundColor Green
Write-Host "Skipped files : $skipped"  -ForegroundColor Yellow

# Build master seal from sorted entries
$sorted = $entries | Sort-Object path
$concat = ($sorted | ForEach-Object { "{0}|{1}" -f $_.path, $_.hash }) -join "`n"

$bytes    = [System.Text.Encoding]::UTF8.GetBytes($concat)
$sha      = [System.Security.Cryptography.SHA256]::Create()
$sealBytes= $sha.ComputeHash($bytes)
$seal     = ($sealBytes | ForEach-Object { $_.ToString("x2") }) -join ""

$sealObj = [pscustomobject]@{
    seal      = $seal
    createdAt = (Get-Date).ToString("o")
    entries   = $sorted
}

$sealObj | ConvertTo-Json -Depth 6 | Set-Content -Path $outJson -Encoding UTF8
Copy-Item $outJson $latestJson -Force

Write-Host ""
Write-Host "Master seal: $seal" -ForegroundColor Cyan
Write-Host "Seal JSON  : $outJson" -ForegroundColor Green
Write-Host "Latest ptr : $latestJson" -ForegroundColor Green
Write-Host "=== Phase203 COMPLETE ===" -ForegroundColor Cyan
'@

Set-Content -Path $phase203Path -Value $phase203 -Encoding UTF8
Write-Host "Wrote $phase203Path" -ForegroundColor Green

# --- Phase204 script content ---
$phase204Path = Join-Path $scriptsDir "Phase204-MasterSealVerify.ps1"
$phase204 = @'
param()

Write-Host "=== Phase204: Master Integrity Seal Verification ===" -ForegroundColor Cyan

$ProjectRoot = Split-Path $PSScriptRoot -Parent
$LogDir      = Join-Path $PSScriptRoot "logs\\integrity"
$latestJson  = Join-Path $LogDir "master-seal-latest.json"

if (-not (Test-Path $latestJson)) {
    Write-Host "[FAIL] No master seal JSON found at: $latestJson" -ForegroundColor Red
    exit 1
}

try {
    $sealData = Get-Content $latestJson -Raw | ConvertFrom-Json
}
catch {
    Write-Host "[FAIL] Could not read or parse seal JSON: $latestJson" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

if (-not $sealData.seal -or -not $sealData.entries) {
    Write-Host "[FAIL] Seal JSON missing 'seal' or 'entries' fields." -ForegroundColor Red
    exit 1
}

$expectedSeal  = $sealData.seal.ToString().ToLower()
$baselineCount = $sealData.entries.Count

Write-Host "Using seal file : $latestJson" -ForegroundColor Gray
Write-Host "Expected seal   : $expectedSeal" -ForegroundColor Cyan
Write-Host "Baseline entries: $baselineCount" -ForegroundColor Gray

function Should-SkipFile([string]$fullPath, [string]$root) {
    $rel = $fullPath.Substring($root.Length).TrimStart('\','/')
    if ($rel -like "node_modules/*") { return $true }
    if ($rel -like ".git/*")         { return $true }
    if ($rel -like ".next/*")        { return $true }
    if ($rel -like "scripts/logs/*") { return $true }
    return $false
}

Write-Host ""
Write-Host "Recomputing seal from current files..." -ForegroundColor Gray

$entries = @()
$included = 0
$skipped  = 0

Get-ChildItem -Path $ProjectRoot -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
    $file = $_
    if (Should-SkipFile $file.FullName $ProjectRoot) {
        $skipped++
        return
    }

    try {
        $hash = Get-FileHash -Path $file.FullName -Algorithm SHA256
        $relative = $file.FullName.Substring($ProjectRoot.Length).TrimStart('\','/')
        $entries += [pscustomobject]@{
            path = $relative
            hash = $hash.Hash.ToLower()
        }
        $included++
    }
    catch {
        Write-Warning "Failed to hash: $($file.FullName). Skipping."
        $skipped++
    }
}

Write-Host "Included files: $included" -ForegroundColor Green
Write-Host "Skipped files : $skipped"  -ForegroundColor Yellow

$sorted = $entries | Sort-Object path
$concat = ($sorted | ForEach-Object { "{0}|{1}" -f $_.path, $_.hash }) -join "`n"

$bytes     = [System.Text.Encoding]::UTF8.GetBytes($concat)
$sha       = [System.Security.Cryptography.SHA256]::Create()
$sealBytes = $sha.ComputeHash($bytes)
$currentSeal = ($sealBytes | ForEach-Object { $_.ToString("x2") }) -join ""

Write-Host ""
Write-Host "Expected seal: $expectedSeal" -ForegroundColor Cyan
Write-Host "Current  seal: $currentSeal" -ForegroundColor Cyan

if ($currentSeal -eq $expectedSeal) {
    Write-Host "=== Phase204 COMPLETE - MASTER VERIFIED ===" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "=== Phase204 FAILED - INTEGRITY MISMATCH ===" -ForegroundColor Red
    exit 1
}
'@

Set-Content -Path $phase204Path -Value $phase204 -Encoding UTF8
Write-Host "Wrote $phase204Path" -ForegroundColor Green

Write-Host ""
Write-Host "Installer complete." -ForegroundColor Cyan
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1) Run Phase203 to generate a fresh seal:" -ForegroundColor Gray
Write-Host "       .\\scripts\\Phase203-MasterSeal-FIX.ps1" -ForegroundColor Yellow
Write-Host "  2) Run Phase204 to verify:" -ForegroundColor Gray
Write-Host "       .\\scripts\\Phase204-MasterSealVerify.ps1" -ForegroundColor Yellow
