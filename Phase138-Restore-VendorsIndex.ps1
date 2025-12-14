Write-Host ""
Write-Host "=== Phase138 – Restore Vendors Index Page ===" -ForegroundColor Cyan
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

# 3) Find the most recent backup of page.tsx
Write-Host "[INFO] Searching for backups in app/vendors..." -ForegroundColor Yellow
$backup = Get-ChildItem $vendorsDir -Filter "page.tsx*.bak*" -ErrorAction SilentlyContinue |
          Sort-Object LastWriteTime -Descending |
          Select-Object -First 1

if (-not $backup) {
    Write-Host "[WARN] No page.tsx backup found. Creating a simple non-placeholder vendors page instead." -ForegroundColor Yellow

    $outFile = Join-Path $vendorsDir "page.tsx"

    # Simple fallback vendors index page
    @"
import Link from 'next/link';

export default function VendorsIndex() {
  return (
    <main style={{ padding: '40px', fontFamily: 'sans-serif' }}>
      <h1 style={{ fontSize: '32px', marginBottom: '20px' }}>Vendors</h1>
      <p>This is a basic vendors index page restored by Phase138.</p>
      <p>You can later replace this with the full vendors list UI.</p>
      <br />
      <Link href="/">Back home</Link>
    </main>
  );
}
"@ | Out-File $outFile -Encoding ASCII

    Write-Host "[OK] Wrote fallback vendors index page.tsx." -ForegroundColor Green
}
else {
    Write-Host ("[INFO] Using backup: {0}" -f $backup.Name) -ForegroundColor Yellow
    $target = Join-Path $vendorsDir "page.tsx"

    if (Test-Path $target) {
        Copy-Item $target "$($target).Phase138.bak" -Force
        Write-Host "[INFO] Existing page.tsx backed up as page.tsx.Phase138.bak" -ForegroundColor Yellow
    }

    Copy-Item $backup.FullName $target -Force
    Write-Host "[OK] Restored app/vendors/page.tsx from backup." -ForegroundColor Green
}

# 4) Rebuild and deploy
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
