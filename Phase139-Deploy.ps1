Write-Host ""
Write-Host "=== Phase139 Build + Deploy Truvern ===" -ForegroundColor Cyan
Write-Host ""

# Ensure we are in the project root
if (-not (Test-Path "package.json")) {
    Write-Host "ERROR: Not in project root!" -ForegroundColor Red
    exit
}

# Step 1: Verify required files exist
$vendorsIndex = "app/vendors/page.tsx"
$vendorsDynamic = "app/vendors/[id]/page.tsx"

Write-Host "[INFO] Checking vendor pages..." -ForegroundColor Yellow

if (-not (Test-Path $vendorsIndex)) {
    Write-Host "[ERROR] Missing: $vendorsIndex" -ForegroundColor Red
    exit
}
if (-not (Test-Path $vendorsDynamic)) {
    Write-Host "[ERROR] Missing: $vendorsDynamic" -ForegroundColor Red
    exit
}

Write-Host "[OK] Vendor pages found." -ForegroundColor Green

# Step 2: Install deps (skip if already installed)
Write-Host "[INFO] Installing dependencies..." -ForegroundColor Yellow
npm install

# Step 3: Local build
Write-Host "[INFO] Running next build..." -ForegroundColor Yellow
npm run build

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Build failed." -ForegroundColor Red
    exit
}

Write-Host "[OK] Local build successful." -ForegroundColor Green

# Step 4: Deploy using Vercel CLI
Write-Host "[INFO] Deploying to Vercel..." -ForegroundColor Yellow
vercel --prod --yes

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "[OK] Deployment complete!" -ForegroundColor Green
    Write-Host "Visit: https://truvern.com/vendors"
} else {
    Write-Host "[ERROR] Deployment failed." -ForegroundColor Red
}
