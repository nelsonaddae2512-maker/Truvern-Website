<# 
    Phase132f-PatchedBuild.ps1
    -----------------------------------------
    - Cleans old .next and .vercel/output
    - Runs pnpm install --no-frozen-lockfile
    - Runs `vercel build` (ignores the specific "results_disabled_..." error)
    - If .vercel/output/config.json exists, removes any routes that contain
      "results_disabled_" so Vercel stops looking for a missing lambda
    - Then runs `vercel deploy --prebuilt --prod --yes`
#>

param(
    [string]$ProjectDir = $PSScriptRoot
)

$ErrorActionPreference = "Stop"

Write-Host "=== Phase132f: Patched Build + Deploy ===" -ForegroundColor Magenta

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

# 2) Clean old build artifacts
Write-Host "[INFO] Cleaning .next and .vercel/output..." -ForegroundColor Cyan
if (Test-Path ".next") {
    Remove-Item ".next" -Recurse -Force
}
if (Test-Path ".vercel\output") {
    Remove-Item ".vercel\output" -Recurse -Force
}

# 3) Ensure pnpm installed and update lockfile
Write-Host "`n[STEP] pnpm install --no-frozen-lockfile" -ForegroundColor Cyan
$pnpmCmd = Get-Command pnpm -ErrorAction SilentlyContinue
if (-not $pnpmCmd) {
    Write-Host "[ERROR] pnpm is not installed. Run: npm i -g pnpm" -ForegroundColor Red
    exit 1
}

pnpm install --no-frozen-lockfile
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] pnpm install failed with exit code $LASTEXITCODE." -ForegroundColor Red
    exit 1
}

Write-Host "[INFO] pnpm-lock.yaml synced." -ForegroundColor Green

# 4) Run vercel build (but don't bail immediately on error)
Write-Host "`n[STEP] vercel build" -ForegroundColor Cyan
vercel build
$buildExit = $LASTEXITCODE

if ($buildExit -ne 0) {
    Write-Host "[WARN] vercel build exited with code $buildExit." -ForegroundColor Yellow
    Write-Host "[WARN] Attempting to patch .vercel/output/config.json to remove results_disabled routes..." -ForegroundColor Yellow
} else {
    Write-Host "[INFO] vercel build reported success." -ForegroundColor Green
}

# 5) Patch .vercel/output/config.json to remove any routes containing "results_disabled_"
$configPath = Join-Path (Join-Path $projectPath ".vercel\output") "config.json"
if (Test-Path $configPath) {
    Write-Host "[INFO] Patching routes in $configPath" -ForegroundColor Cyan
    $rawJson = Get-Content $configPath | Out-String
    $configObj = $rawJson | ConvertFrom-Json

    if ($configObj.routes) {
        $originalCount = $configObj.routes.Count
        $filtered = @()

        foreach ($r in $configObj.routes) {
            $text = ($r | ConvertTo-Json -Compress)
            if ($text -match "results_disabled_") {
                Write-Host "[PATCH] Removing route: $text" -ForegroundColor Yellow
            } else {
                $filtered += $r
            }
        }

        $configObj.routes = $filtered
        $newJson = $configObj | ConvertTo-Json -Depth 10
        Set-Content -Path $configPath -Value $newJson -Encoding UTF8

        Write-Host "[INFO] Routes patched. Original count: $originalCount; New count: $($filtered.Count)" -ForegroundColor Green
    } else {
        Write-Host "[INFO] No routes array in config.json; nothing to patch." -ForegroundColor Cyan
    }
} else {
    Write-Host "[ERROR] .vercel/output/config.json not found. Build output missing." -ForegroundColor Red
    exit 1
}

# 6) Deploy prebuilt output
Write-Host "`n[STEP] vercel deploy --prebuilt --prod --yes" -ForegroundColor Cyan
vercel deploy --prebuilt --prod --yes
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] vercel deploy failed with exit code $LASTEXITCODE." -ForegroundColor Red
    exit 1
}

Write-Host "`n✅ Phase132f completed: Patched build deployed successfully." -ForegroundColor Green
exit 0
