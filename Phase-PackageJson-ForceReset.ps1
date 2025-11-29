Write-Host "== Truvern package.json FORCE RESET ==" -ForegroundColor Cyan

# 1. Confirm working directory
$projPath = "C:\Users\MR.NELSON\Downloads\truvern"
Set-Location $projPath
Write-Host "Working directory: $projPath" -ForegroundColor Yellow

# 2. Backup current package.json if it exists
$timestamp = Get-Date -Format "yyyyMMddHHmmss"
if (Test-Path ".\package.json") {
    $backupPath = ".\package.json.broken.$timestamp.json"
    Copy-Item ".\package.json" $backupPath -Force
    Write-Host "Backed up existing package.json to $backupPath" -ForegroundColor DarkYellow
} else {
    Write-Host "No existing package.json found; nothing to back up." -ForegroundColor DarkYellow
}

# 3. Write a CLEAN, known-good package.json (UTF-8 **without BOM**)
$json = @'
{
  "name": "truvern",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "npx prisma generate && next build",
    "start": "next start",
    "lint": "next lint",
    "postinstall": "prisma generate"
  },
  "dependencies": {
    "@prisma/client": "^6.0.0",
    "next": "15.5.6",
    "react": "^18.3.1",
    "react-dom": "^18.3.1"
  },
  "devDependencies": {
    "autoprefixer": "^10.4.20",
    "postcss": "^8.4.47",
    "prisma": "^6.0.0",
    "tailwindcss": "^3.4.14",
    "typescript": "^5.5.0",
    "eslint": "^8.57.0",
    "eslint-config-next": "15.5.6"
  }
}
'@

# Use .NET to write UTF-8 WITHOUT BOM (avoids hidden bytes that break JSON.parse)
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText((Join-Path $projPath "package.json"), $json, $utf8NoBom)

Write-Host "New package.json written with UTF-8 (no BOM)." -ForegroundColor Green

# 4. Show the first few lines so we know it's clean
Write-Host "`n--- package.json preview ---" -ForegroundColor Yellow
Get-Content ".\package.json" | Select-Object -First 10 | ForEach-Object { Write-Host $_ }
Write-Host "----------------------------`n" -ForegroundColor Yellow

# 5. Remove build artefacts and lockfiles
Write-Host "Removing .next, node_modules and package-lock.json..." -ForegroundColor Yellow
Remove-Item -Recurse -Force ".\node_modules" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force ".\.next" -ErrorAction SilentlyContinue
Remove-Item ".\package-lock.json" -Force -ErrorAction SilentlyContinue

# 6. Fresh install
Write-Host "`nRunning npm install (this may take a few minutes)..." -ForegroundColor Cyan
npm install

if ($LASTEXITCODE -ne 0) {
    Write-Host "npm install failed (exit code $LASTEXITCODE). Fix that first." -ForegroundColor Red
    exit 1
}

Write-Host "npm install completed successfully." -ForegroundColor Green

# 7. Quick sanity check that tailwindcss is present
if (Test-Path ".\node_modules\tailwindcss\package.json") {
    Write-Host "tailwindcss found in node_modules ✅" -ForegroundColor Green
} else {
    Write-Host "tailwindcss NOT found in node_modules ❌" -ForegroundColor Red
}

# 8. Try a clean build
Write-Host "`nRunning npm run build..." -ForegroundColor Cyan
npm run build
Write-Host "`n== Force reset script finished ==" -ForegroundColor Cyan
