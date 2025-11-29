# Phase-PackageJson-Rebuild.ps1
# Completely rewrites package.json with a known-good config for Truvern

$ErrorActionPreference = "Stop"

Write-Host "== Truvern package.json REBUILD ==" -ForegroundColor Cyan
Set-Location "C:\Users\MR.NELSON\Downloads\truvern"

# Backup any existing package.json first
if (Test-Path "package.json") {
    $timestamp = Get-Date -Format "yyyyMMddHHmmss"
    $backupPath = "package.rebuild-backup.$timestamp.json"
    Copy-Item "package.json" $backupPath -Force
    Write-Host "Existing package.json backed up as $backupPath" -ForegroundColor Yellow
}

# Known-good package.json contents
$json = @'
{
  "name": "truvern",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "npx prisma generate && next build",
    "start": "next start",
    "lint": "next lint",
    "postinstall": "prisma generate"
  },
  "dependencies": {
    "@prisma/client": "^6.18.0",
    "prisma": "^6.18.0",
    "next": "15.5.6",
    "react": "18.3.1",
    "react-dom": "18.3.1",
    "tailwindcss": "3.4.14",
    "postcss": "8.4.47",
    "autoprefixer": "10.4.20",
    "@sentry/nextjs": "^8.0.0",
    "@opentelemetry/api": "^1.9.0"
  },
  "devDependencies": {
    "typescript": "^5.6.3",
    "@types/node": "^22.7.4",
    "@types/react": "^18.3.12",
    "@types/react-dom": "^18.3.1",
    "eslint": "^9.13.0",
    "eslint-config-next": "^15.0.0"
  }
}
'@

# Overwrite package.json with the clean JSON
$json | Set-Content -Path "package.json" -Encoding UTF8

Write-Host "package.json has been rebuilt." -ForegroundColor Green

# Quick validation using PowerShell's JSON parser
try {
    Get-Content "package.json" -Raw | ConvertFrom-Json | Out-Null
    Write-Host "package.json is valid JSON." -ForegroundColor Green
} catch {
    Write-Host "ERROR: package.json is still invalid JSON:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

Write-Host "You can inspect it with:  notepad package.json" -ForegroundColor Cyan
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1) npm install" -ForegroundColor Cyan
Write-Host "  2) npm run build" -ForegroundColor Cyan
