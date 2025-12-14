Write-Host "=== Standard Vercel Deploy (build + prod) ===" -ForegroundColor Cyan

$Root = "C:\Users\MR.NELSON\Downloads\truvern"
Set-Location $Root

if (-not (Test-Path "node_modules")) {
    Write-Host "node_modules not found. Running npm install..." -ForegroundColor Yellow
    npm install
    if ($LASTEXITCODE -ne 0) {
        Write-Host "npm install failed." -ForegroundColor Red
        exit 1
    }
}

Write-Host "Running npm run build..." -ForegroundColor Cyan
npm run build
if ($LASTEXITCODE -ne 0) {
    Write-Host "Build failed. Aborting deploy." -ForegroundColor Red
    exit 1
}

Write-Host "Running vercel --prod..." -ForegroundColor Cyan
vercel --prod --confirm --yes
if ($LASTEXITCODE -ne 0) {
    Write-Host "Vercel deploy failed." -ForegroundColor Red
    exit 1
}

Write-Host "=== Deploy complete. Site updated in production. ===" -ForegroundColor Green
