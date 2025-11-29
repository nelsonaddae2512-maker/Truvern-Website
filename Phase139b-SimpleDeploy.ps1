Write-Host ""
Write-Host "=== Phase139b SIMPLE Build + Deploy Truvern ===" -ForegroundColor Cyan
Write-Host ""

# 1) Safety: prevent System32 runs
if ($PWD.Path -match "System32") {
    Write-Host "ERROR: Do not run from System32. cd into the truvern folder first." -ForegroundColor Red
    exit
}

# 2) Ensure project root
if (-not (Test-Path "package.json")) {
    Write-Host "ERROR: package.json not found. You are not in the project root." -ForegroundColor Red
    exit
}

Write-Host "Project root OK." -ForegroundColor Green
Write-Host ""

# 3) Install dependencies
Write-Host "Running npm install..." -ForegroundColor Yellow
npm install
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: npm install failed." -ForegroundColor Red
    exit
}

Write-Host "npm install complete." -ForegroundColor Green
Write-Host ""

# 4) Build Next.js
Write-Host "Running npm run build..." -ForegroundColor Yellow
npm run build
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: npm run build failed." -ForegroundColor Red
    exit
}

Write-Host "Build completed successfully." -ForegroundColor Green
Write-Host ""

# 5) Deploy to Vercel
Write-Host "Deploying to Vercel (prod)..." -ForegroundColor Yellow
vercel --prod --yes
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Vercel deploy failed." -ForegroundColor Red
    exit
}

Write-Host ""
Write-Host "=== Phase139b Deployment Successful ===" -ForegroundColor Green
Write-Host "Check vendors page:" -ForegroundColor Green
Write-Host "https://truvern.com/vendors" -ForegroundColor Green
