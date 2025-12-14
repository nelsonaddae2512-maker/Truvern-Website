# Phase203-MasterIntegritySeal.ps1
# Truvern - Master Integrity Seal
# Computes SHA256 hashes for key project files and produces:
# - A markdown report under scripts\logs\integrity
# - A JSON seal summary with the master checksum

param()

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
Write-Host "=== Phase203: Master Integrity Seal ===" -ForegroundColor Cyan
Write-Host ""

# ---------------------------
# Resolve project root
# ---------------------------

# scripts folder is PSScriptRoot; project is its parent
$scriptsRoot = $PSScriptRoot
$projectRoot = Split-Path $scriptsRoot -Parent

Set-Location $projectRoot
Log ("Project root: " + $projectRoot)

# ---------------------------
# Prepare log directory + file names
# ---------------------------

$logDir = Join-Path $scriptsRoot "logs\integrity"
if (!(Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    Log ("Created log directory: " + $logDir)
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$mdReportPath = Join-Path $logDir ("Phase203-MasterSeal-" + $timestamp + ".md")
$jsonSealPath = Join-Path $logDir ("Phase203-MasterSeal-" + $timestamp + ".json")

# ---------------------------
# Build file list to hash
# ---------------------------

$includeDirs = @(
    "app",
    "prisma",
    "public",
    "scripts"
)

$includeFiles = @(
    "package.json",
    "next.config.js",
    "next.config.mjs",
    "tsconfig.json",
    "tailwind.config.js",
    "postcss.config.js",
    ".env"
)

$files = @()

foreach ($dir in $includeDirs) {
    $full = Join-Path $projectRoot $dir
    if (Test-Path $full) {
        Log ("Scanning directory: " + $full)
        $dirFiles = Get-ChildItem -Path $full -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object {
                $_.FullName -notmatch "\\node_modules\\" -and
                $_.FullName -notmatch "\\\.next\\" -and
                $_.FullName -notmatch "\\logs\\"
            }
        $files += $dirFiles
    } else {
        Warn ("Directory not found (skipped): " + $dir)
    }
}

foreach ($fileName in $includeFiles) {
    $full = Join-Path $projectRoot $fileName
    if (Test-Path $full) {
        $item = Get-Item $full
        $files += $item
        Log ("Added file: " + $item.FullName)
    } else {
        Warn ("File not found (optional): " + $fileName)
    }
}

# Remove duplicates (same full path)
$files = $files | Sort-Object FullName -Unique

if ($files.Count -eq 0) {
    Fail "No files found to hash. Nothing to seal."
    exit 1
}

Ok ("Total files included in seal: " + $files.Count)

# ---------------------------
# Compute per-file hashes
# ---------------------------

$fileRecords = @()

foreach ($f in $files) {
    try {
        $hash = Get-FileHash -Algorithm SHA256 -Path $f.FullName
        # relative path for portability
        $rel = $f.FullName.Substring($projectRoot.Length).TrimStart("\","/")
        $rec = "" | Select-Object RelativePath, Length, Hash
        $rec.RelativePath = $rel
        $rec.Length = $f.Length
        $rec.Hash = $hash.Hash.ToLower()
        $fileRecords += $rec
    }
    catch {
        Warn ("Failed to hash file: " + $f.FullName + " - " + $_.Exception.Message)
    }
}

# ---------------------------
# Compute master seal hash
# ---------------------------

# Concatenate "path|hash" lines sorted by path
$concatLines = @()
foreach ($rec in ($fileRecords | Sort-Object RelativePath)) {
    $concatLines += ($rec.RelativePath + "|" + $rec.Hash)
}
$concatText = [string]::Join("`n", $concatLines)

$sha256 = [System.Security.Cryptography.SHA256]::Create()
$bytes = [System.Text.Encoding]::UTF8.GetBytes($concatText)
$hashBytes = $sha256.ComputeHash($bytes)
$masterSeal = -join ($hashBytes | ForEach-Object { $_.ToString("x2") })

Ok ("Master seal hash (SHA256): " + $masterSeal)

# ---------------------------
# Build markdown report
# ---------------------------

$lines = @()

$lines += "# Phase203 Master Integrity Seal"
$lines += ""
$lines += ("Generated: " + (Get-Date -Format u))
$lines += ("Project root: " + $projectRoot)
$lines += ""
$lines += "## Master Seal"
$lines += ""
$lines += "Algorithm: SHA256"
$lines += ("File count: " + $fileRecords.Count)
$lines += ""
$lines += "```text"
$lines += $masterSeal
$lines += "```"
$lines += ""
$lines += "## File Hashes (sample)"
$lines += ""
$lines += "Showing up to the first 50 files included in the seal."
$lines += ""
$lines += "| Relative path | Size (bytes) | SHA256 |"
$lines += "|---------------|--------------|--------|"

$sample = $fileRecords | Sort-Object RelativePath | Select-Object -First 50
foreach ($rec in $sample) {
    $line = "| " + $rec.RelativePath + " | " + $rec.Length + " | " + $rec.Hash + " |"
    $lines += $line
}

$mdBody = $lines -join "`r`n"
Set-Content -Path $mdReportPath -Value $mdBody -Encoding UTF8

# ---------------------------
# Build JSON seal file
# ---------------------------

$sealObject = [PSCustomObject]@{
    GeneratedAt = (Get-Date).ToString("u")
    ProjectRoot = $projectRoot
    Algorithm   = "SHA256"
    FileCount   = $fileRecords.Count
    MasterSeal  = $masterSeal
    Files       = ($fileRecords | Sort-Object RelativePath)
}

$sealJson = $sealObject | ConvertTo-Json -Depth 4
Set-Content -Path $jsonSealPath -Value $sealJson -Encoding UTF8

Write-Host ""
Write-Host ("Markdown report: " + $mdReportPath) -ForegroundColor Yellow
Write-Host ("JSON seal file: " + $jsonSealPath) -ForegroundColor Yellow
Write-Host "===== Phase203 COMPLETE =====" -ForegroundColor Cyan
Write-Host ""
