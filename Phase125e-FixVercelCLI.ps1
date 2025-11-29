# Phase125e-FixVercelCLI.ps1 (patched)
$ErrorActionPreference = "Stop"

Write-Host "=== Phase125e: Fix Vercel CLI Inheritance ===" -ForegroundColor Cyan

$npmPath = "C:\Users\MR.NELSON\AppData\Roaming\npm"

if (-not (Test-Path $npmPath)) {
  Write-Host "❌ npm global path not found at $npmPath" -ForegroundColor Red
  exit 1
}

if ($env:Path -notlike "*$npmPath*") {
  $env:Path += ";$npmPath"
  [Environment]::SetEnvironmentVariable("Path", $env:Path, "User")
  Write-Host "✅ Added npm global path to PATH." -ForegroundColor Green
} else {
  Write-Host "ℹ️ npm path already exists in PATH." -ForegroundColor Yellow
}

# Confirm via cmd (more reliable for .cmd wrappers)
try {
  $vercelVersion = (cmd /c "vercel --version" 2>&1 | Out-String).Trim()
  if ($vercelVersion -match "Vercel CLI") {
    Write-Host "✅ Vercel CLI active: $vercelVersion" -ForegroundColor Green
  } else {
    throw "Vercel CLI not responding correctly."
  }
} catch {
  Write-Host "❌ Vercel CLI not available. Please reinstall with: npm i -g vercel" -ForegroundColor Red
  exit 1
}

Write-Host "=== PATH fix confirmed ===" -ForegroundColor Cyan
Read-Host "Press Enter to close..."
