# Phase125b-FixVercelPath.ps1
# Simple verified PowerShell path repair for npm + vercel

Write-Host ""
Write-Host "=== Phase125b: Fix Vercel Path ===" -ForegroundColor Cyan

$npmPath = "$env:APPDATA\npm"
Write-Host ("Checking npm global path: " + $npmPath) -ForegroundColor Yellow

if (Test-Path $npmPath) {
    if (-not ($env:Path -split ';' | Where-Object { $_ -eq $npmPath })) {
        $env:Path += ";" + $npmPath
        [Environment]::SetEnvironmentVariable("Path", $env:Path, "User")
        Write-Host "Added npm global path to PATH." -ForegroundColor Green
    } else {
        Write-Host "npm path already exists in PATH." -ForegroundColor DarkGray
    }
} else {
    Write-Host "npm path not found: $npmPath" -ForegroundColor Red
}

# Verify vercel availability
$vercelVersion = & vercel --version 2>$null
if ($vercelVersion) {
    Write-Host ("Vercel CLI found: " + $vercelVersion) -ForegroundColor Green
} else {
    Write-Host "Vercel CLI not found. Run: npm i -g vercel" -ForegroundColor Red
    Read-Host "Press Enter to close..."
    exit
}

Write-Host "Launching Safe Alias phase..." -ForegroundColor Cyan
Start-Process powershell -ArgumentList "-NoLogo -ExecutionPolicy Bypass -File .\Phase125-SafeAlias.ps1" -Verb RunAs

Write-Host ""
Write-Host "=== Fix Completed ===" -ForegroundColor Green
Read-Host "Press Enter to close..."
