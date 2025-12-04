Write-Host "===== Phase181: Evidence Panel & List API START =====" -ForegroundColor Yellow

$root = "C:\Users\MR.NELSON\Downloads\truvern"
$vendorsPath = Join-Path $root "app\vendors"

# Literal [id] folder
$paramPath = Join-Path $vendorsPath "[id]"

Write-Host "Current Directory: $root" -ForegroundColor Cyan

# Use .NET directory check because Test-Path fails on bracket names
$exists = [System.IO.Directory]::Exists($paramPath)

if (-not $exists) {
    Write-Host "Vendor detail directory NOT found at: $paramPath" -ForegroundColor Red
    Write-Host "Phase181 cannot continue until app\vendors\[id] exists." -ForegroundColor Red
    exit
}

Write-Host "Vendor detail directory FOUND: $paramPath" -ForegroundColor Green

# Create evidence list API directory
$evidenceListDir = Join-Path $root "app\api\evidence\list"

if (!(Test-Path $evidenceListDir)) {
    New-Item -ItemType Directory -Force -Path $evidenceListDir | Out-Null
    Write-Host "Created folder: $evidenceListDir" -ForegroundColor Green
}

# Create route.ts file
$routeFile = Join-Path $evidenceListDir "route.ts"

$routeContent = @"
import { NextResponse } from 'next/server';

export async function GET() {
  return NextResponse.json({
    ok: true,
    message: "Evidence list endpoint is live"
  });
}
"@

Set-Content -Path $routeFile -Value $routeContent -Encoding UTF8

Write-Host "Evidence list API route created: $routeFile" -ForegroundColor Green

Write-Host "Phase181 COMPLETE." -ForegroundColor Green
