Param(
    [string]$ProjectDir = "C:\Users\MR.NELSON\Downloads\truvern"
)

# Move into the project directory
Set-Location $ProjectDir

Write-Host "=== Phase-CLI-Deploy.ps1 starting ===" -ForegroundColor Cyan
Write-Host "Project directory: $ProjectDir" -ForegroundColor DarkCyan

# Basic sanity check
if (-not (Test-Path "package.json")) {
    Write-Error "package.json not found in $ProjectDir. Are you in the correct project folder?"
    exit 1
}

# Ensure dependencies are installed
if (-not (Test-Path "node_modules")) {
    Write-Host "node_modules not found. Running npm install..." -ForegroundColor Yellow
    npm install
    if ($LASTEXITCODE -ne 0) {
        Write-Error "npm install failed with exit code $LASTEXITCODE"
        exit 1
    }
} else {
    Write-Host "node_modules already present. Skipping npm install." -ForegroundColor DarkYellow
}

# Run Next.js build
Write-Host "Running npm run build..." -ForegroundColor Yellow
npm run build
$buildExitCode = $LASTEXITCODE

if ($buildExitCode -ne 0) {
    Write-Error "npm run build failed with exit code $buildExitCode"
    exit 1
}

Write-Host "npm run build completed successfully." -ForegroundColor Green

# Ensure Vercel CLI is available
if (-not (Get-Command vercel -ErrorAction SilentlyContinue)) {
    Write-Host "Vercel CLI not found. Installing as dev dependency..." -ForegroundColor Yellow
    npm install vercel --save-dev
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Vercel CLI install failed with exit code $LASTEXITCODE"
        exit 1
    }
}

# Run Vercel deploy (production)
Write-Host "Running Vercel production deploy..." -ForegroundColor Yellow
npx vercel --prod --yes
$deployExitCode = $LASTEXITCODE

if ($deployExitCode -ne 0) {
    Write-Error "Vercel deploy failed with exit code $deployExitCode"
    exit 1
}

Write-Host "CLI deploy script complete." -ForegroundColor Green
