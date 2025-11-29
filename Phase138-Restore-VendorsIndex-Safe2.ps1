Write-Host ""
Write-Host "=== Phase138 SAFE Restore Vendors Index Page ===" -ForegroundColor Cyan
Write-Host ""

# Safety: prevent running from system32
if ($PWD.Path -match "system32") {
    Write-Host "ERROR: Do not run from system32. Navigate to the truvern folder first." -ForegroundColor Red
    exit
}

# Ensure project root
if (-not (Test-Path "package.json")) {
    Write-Host "ERROR: package.json not found. You are not in the project root." -ForegroundColor Red
    exit
}

# Vendors directory
$vendorsDir = "app/vendors"
if (-not (Test-Path $vendorsDir)) {
    Write-Host "ERROR: app/vendors folder does not exist." -ForegroundColor Red
    exit
}

# Locate newest backup
Write-Host "Searching for backups in app/vendors..." -ForegroundColor Yellow

$backup = Get-ChildItem $vendorsDir -Filter "page.tsx.bak*" `
          | Sort-Object LastWriteTime -Descending `
          | Select-Object -First 1

if (-not $backup) {
    Write-Host "WARNING: No backup files found. Cannot restore." -ForegroundColor Yellow
    exit
}

Write-Host ("Using backup file: {0}" -f $backup.Name) -ForegroundColor Yellow

# Backup current file if exists
$target = Join-Path $vendorsDir "page.tsx"

if (Test-Path $target) {
    $backupTarget = "$target.Phase138.bak"
    Copy-Item $target $backupTarget -Force
    Write-Host ("Backed up current page.tsx as: {0}" -f $backupTarget) -ForegroundColor Yellow
}

# Copy backup → restore
Copy-Item $backup.FullName $target -Force
Write-Host "Restored vendors/page.tsx from backup." -ForegroundColor Green

# Notify completed
Write-Host ""
Write-Host "Phase138 restore completed." -ForegroundColor Green
