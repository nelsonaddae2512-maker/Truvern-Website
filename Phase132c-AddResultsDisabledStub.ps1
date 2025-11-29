<# 
    Phase132c-AddResultsDisabledStub.ps1
    -----------------------------------------
    - Ensures app/assessment/results_disabled_20251113-001245/page.tsx exists
    - This gives Vercel a lambda for route /assessment/results_disabled_20251113-001245
      so "Unable to find lambda for route" no longer occurs.
#>

param(
    [string]$ProjectDir = $PSScriptRoot
)

$ErrorActionPreference = "Stop"

Write-Host "=== Phase132c: Add Results Disabled Stub Route ===" -ForegroundColor Magenta

# 1) Normalise working directory
try {
    if (-not $ProjectDir -or $ProjectDir -eq "") {
        $ProjectDir = $PSScriptRoot
    }
    $projectPath = Resolve-Path $ProjectDir
} catch {
    Write-Host "[ERROR] Unable to resolve ProjectDir." -ForegroundColor Red
    exit 1
}

if ($PWD.Path -like "*System32*") {
    Set-Location $projectPath
} else {
    Set-Location $projectPath
}

Write-Host "[INFO] Working in: $((Get-Location).Path)" -ForegroundColor Cyan

# 2) Target folder for the stub route
$stubDir = Join-Path $projectPath "app\assessment\results_disabled_20251113-001245"
$stubPage = Join-Path $stubDir "page.tsx"

if (-not (Test-Path $stubDir)) {
    Write-Host "[INFO] Creating directory: $stubDir" -ForegroundColor Yellow
    New-Item -Path $stubDir -ItemType Directory -Force | Out-Null
} else {
    Write-Host "[INFO] Directory already exists: $stubDir" -ForegroundColor Cyan
}

# 3) Create stub page.tsx
$pageContent = @"
export const dynamic = "force-static";

export default function LegacyResultsDisabledPage() {
  return (
    <main className="min-h-screen flex items-center justify-center p-8">
      <div className="max-w-md text-center space-y-4">
        <h1 className="text-2xl font-semibold">Legacy results route disabled</h1>
        <p className="text-sm text-gray-500">
          This older assessment results route has been disabled. 
          Please use the main Truvern reports and board dashboards instead.
        </p>
      </div>
    </main>
  );
}
"@

Write-Host "[INFO] Writing stub page: $stubPage" -ForegroundColor Yellow
Set-Content -Path $stubPage -Value $pageContent -Encoding UTF8

Write-Host "✅ Phase132c complete. Stub route created for /assessment/results_disabled_20251113-001245." -ForegroundColor Green

exit 0
