<# 
  Phase213-LogoAudit.ps1
  -----------------------
  Scan the Truvern project for old / inconsistent logo paths and rewrite them
  to the canonical path: /brand/truvern-shield.svg

  - Verifies the logo file exists in public/brand
  - Scans .tsx/.ts/.js/.jsx/.mjs/.cjs/.json/.css/.scss/.md config & source
  - Skips node_modules, .next, .vercel, .vercel-tools, .git
  - Writes .bak-phase213 backups for any modified files
#>

param(
    [string]$ProjectRoot = ""
)

Write-Host "=== Phase213: Logo Audit & Auto-Fix ===" -ForegroundColor Cyan

# Resolve project root (default: current directory)
if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = (Get-Location).Path
}

# Basic sanity check: ensure we are in the truvern folder
$folderName = Split-Path $ProjectRoot -Leaf
if ($folderName -ne "truvern") {
    Write-Host "Warning: Project root is '$ProjectRoot' (folder '$folderName'), expected 'truvern'." -ForegroundColor Yellow
    Write-Host "You can re-run with:  .\scripts\Phase213-LogoAudit.ps1 -ProjectRoot 'C:\Users\MR.NELSON\Downloads\truvern'" -ForegroundColor Yellow
} else {
    Write-Host "Project root detected: $ProjectRoot" -ForegroundColor Green
}

# 1) Verify logo file exists
$logoRelativePath = "public\brand\truvern-shield.svg"
$logoFullPath = Join-Path $ProjectRoot $logoRelativePath

if (Test-Path $logoFullPath) {
    Write-Host "Logo file found: $logoFullPath" -ForegroundColor Green
} else {
    Write-Host "WARNING: Logo file not found at expected path:" -ForegroundColor Red
    Write-Host "         $logoFullPath" -ForegroundColor Red
    Write-Host "Create or copy truvern-shield.svg into /public/brand before deploying." -ForegroundColor Yellow
}

# 2) Define known old/bad logo paths to replace
#    You can extend this list later if you discover more variants.
$oldLogoPatterns = @(
    "/truvern-logo-mark.svg",
    "/brand/truvern-logo-mark.svg",
    "/truvern-logo.svg",
    "/brand/truvern-logo.svg",
    "/logo.svg",
    "/brand/logo.svg"
)

$canonicalLogoPath = "/brand/truvern-shield.svg"

Write-Host ""
Write-Host "Canonical logo path: $canonicalLogoPath" -ForegroundColor Cyan
Write-Host "Scanning for old logo references..." -ForegroundColor Cyan

# 3) Get candidate files (exclude big / generated dirs)
$includeExtensions = @("*.tsx","*.ts","*.jsx","*.js","*.mjs","*.cjs","*.json","*.css","*.scss","*.md","*.mjs","*.mjsx")
$excludeDirs = @("node_modules",".next",".vercel",".vercel-tools",".git")

$files = Get-ChildItem -Path $ProjectRoot -Recurse -File -Include $includeExtensions |
    Where-Object {
        # Filter out excluded directories
        $relative = $_.FullName.Substring($ProjectRoot.Length).TrimStart('\')
        foreach ($ex in $excludeDirs) {
            if ($relative -like "$ex\*") { return $false }
            if ($relative -like "$ex/*") { return $false }
        }
        return $true
    }

Write-Host ("Files scanned: {0}" -f $files.Count) -ForegroundColor DarkCyan

$changedFiles = @()
$totalReplacements = 0

foreach ($file in $files) {
    $content = Get-Content -LiteralPath $file.FullName -Raw
    $originalContent = $content

    foreach ($old in $oldLogoPatterns) {
        if ($content.Contains($old)) {
            $content = $content.Replace($old, $canonicalLogoPath)
        }
    }

    if ($content -ne $originalContent) {
        # Make backup
        $backupPath = "$($file.FullName).bak-phase213"
        if (-not (Test-Path $backupPath)) {
            Copy-Item -LiteralPath $file.FullName -Destination $backupPath
        }

        # Write updated file
        Set-Content -LiteralPath $file.FullName -Value $content -NoNewline

        # Count replacements roughly (for reporting)
        $before = ($originalContent.Length)
        $after  = ($content.Length)
        # We can't easily count exact replacements without more parsing,
        # but we can at least track changed files.
        $changedFiles += $file.FullName
    }
}

# Re-count replacements more accurately using Select-String
foreach ($filePath in $changedFiles | Select-Object -Unique) {
    $fileContent = Get-Content -LiteralPath $filePath -Raw
    foreach ($old in $oldLogoPatterns) {
        $matchCount = ([regex]::Matches($fileContent, [regex]::Escape($old))).Count
        # Should be zero, but we'll still evaluate for completeness
        if ($matchCount -gt 0) {
            # If anything remains, we might want to know
            Write-Host "Note: Remaining references to $old in $filePath" -ForegroundColor Yellow
        }
    }

    $canonicalCount = ([regex]::Matches($fileContent, [regex]::Escape($canonicalLogoPath))).Count
    $totalReplacements += $canonicalCount
}

Write-Host ""
Write-Host "=== Phase213 Summary ===" -ForegroundColor Cyan

if ($changedFiles.Count -eq 0) {
    Write-Host "No files required changes. All logo paths already canonical." -ForegroundColor Green
} else {
    $uniqueChanged = $changedFiles | Select-Object -Unique
    Write-Host ("Files updated: {0}" -f $uniqueChanged.Count) -ForegroundColor Green
    Write-Host ("Approximate occurrences of canonical logo path after rewrite: {0}" -f $totalReplacements) -ForegroundColor Green
    Write-Host ""
    Write-Host "Backup files (.bak-phase213) were created alongside each modified file." -ForegroundColor DarkYellow
}

Write-Host ""
Write-Host "Phase213 COMPLETE: Logo audit & patch finished." -ForegroundColor Cyan
