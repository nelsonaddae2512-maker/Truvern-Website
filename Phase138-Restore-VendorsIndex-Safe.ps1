Write-Host ""
Write-Host "=== Phase138 – SAFE Restore Vendors Index Page ===" -ForegroundColor Cyan
Write-Host ""

# 1) Safety checks
if ($PWD.Path -match "System32") {
    Write-Host "[ERROR] Do not run from System32. cd into the truvern folder first." -ForegroundColor Red
    exit
}

if (-not (Test-Path "package.json")) {
    Write-Host "[ERROR] package.json not found. This is not the project root." -ForegroundColor Red
    exit
}

# 2) Ensure vendors folder exists
$vendorsDir = "app/vendors"
if (-not (Test-Path $vendorsDir)) {
    Write-Host "[ERROR] app/vendors folder not found." -ForegroundColor Red
    exit
}

# 3) Find the most recent backup of page.tsx (no JSX involved)
Write-Host "[INFO] Searching for backups in app/vendors..." -ForegroundColor Yellow

$backup = Get-ChildItem $vendorsDir -Filter "page.tsx.bak*" -ErrorAction SilentlyContinue |
          Sort-Object LastWriteTime -Descending |
          Select-Object -First 1

if (-not $backup) {
    Write-Host "[WARN] No page.tsx.bak* backup found in app/vendors." -ForegroundColor Yellow
    Write-Host "[WARN] Vendors index will stay as the current Phase118 placeholder." -ForegroundColor Yellow
    Write-Host "=== Phase138 Completed (no backup to restore) ===" -ForegroundColor Green
    exit
}

Write-Host ("[INFO] Using backup file: {0}" -f $backup.Name) -ForegroundColor Yellow

# 4) Backup current page.tsx (if it exists)
$target = Join-Path $vendorsDir "page.tsx"

if (Test-Path $target) {
    $backupTarget = "$target.Phase138.bak"
    Copy-Item $target $backupTarget -Force
    Write-Host ("[INFO] Current page.tsx backed up as: {0}" -f (Split-Path $backupTarget -Leaf)) -ForegroundColor Yellow
}

# 5) Restore vendors index from backup
Copy-Item $backup.FullName $target -Force
Write-Host "[OK] Restored app/vendors/page.tsx from backup." -ForegroundColor Green

# 6) Build and deploy (no JSX here either)
Write-Host ""
Write-Host "[INFO] Running build..." -ForegroundColor Yellow

if (Test-Path "pnpm-lock.yaml") {
    pnpm run build
}
elseif (Test-Path "yarn.lock") {
    yarn build
}
else {
    npm run build
}

Write-Host "[OK] Build complete." -ForegroundColor Green

Write-Host "[INFO] Deploying to Vercel (prod)..." -ForegroundColor Yellow
vercel deploy --prod --yes

Write-Host ""
Write-Host "=== Phase138 Completed – Vendors index restored and deployed ===" -ForegroundColor Green
