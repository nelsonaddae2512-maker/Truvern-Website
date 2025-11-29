<# 
    Phase132d-AddResultsDisabledAPIRoute.ps1
    -----------------------------------------
    - Creates stub API route:
      app/api/assessment/results_disabled_20251113-001245/route.ts
    - Allows Vercel to generate a lambda so build stops breaking.
#>

param(
    [string]$ProjectDir = $PSScriptRoot
)

$ErrorActionPreference = "Stop"

Write-Host "=== Phase132d: Add Disabled Results API Route ===" -ForegroundColor Magenta

# Normalize working directory
try {
    if (-not $ProjectDir -or $ProjectDir -eq "") {
        $ProjectDir = $PSScriptRoot
    }
    $projectPath = Resolve-Path $ProjectDir
} catch {
    Write-Host "[ERROR] Unable to resolve project directory." -ForegroundColor Red
    exit 1
}

if ($PWD.Path -like "*System32*") {
    Set-Location $projectPath
} else {
    Set-Location $projectPath
}

Write-Host "[INFO] Working in: $((Get-Location).Path)" -ForegroundColor Cyan

# Stub API route path
$stubDir = Join-Path $projectPath "app\api\assessment\results_disabled_20251113-001245"
$stubRoute = Join-Path $stubDir "route.ts"

# Create folder if needed
if (-not (Test-Path $stubDir)) {
    Write-Host "[INFO] Creating directory: $stubDir" -ForegroundColor Yellow
    New-Item -Path $stubDir -ItemType Directory -Force | Out-Null
} else {
    Write-Host "[INFO] Directory already exists: $stubDir" -ForegroundColor Cyan
}

# Create stub API route
$routeContent = @"
import { NextResponse } from "next/server";

export async function GET() {
  return NextResponse.json({
    status: "disabled",
    message: "This legacy assessment results route has been disabled."
  });
}

export async function POST() {
  return NextResponse.json({
    status: "disabled",
    message: "POST not allowed. This route is deprecated."
  });
}
"@

Write-Host "[INFO] Writing route.ts: $stubRoute" -ForegroundColor Yellow
Set-Content -Path $stubRoute -Value $routeContent -Encoding UTF8

Write-Host "✅ Phase132d complete. API stub created." -ForegroundColor Green

exit 0
