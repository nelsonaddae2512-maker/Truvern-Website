Write-Host ""
Write-Host "=== Phase137 – Safe Vendor Placeholder Fix ===" -ForegroundColor Cyan
Write-Host ""

# Ensure not in System32
if ($PWD.Path -match "System32") {
    Write-Host "[ERROR] Do not run from System32." -ForegroundColor Red
    exit
}

# Ensure project root
if (-not (Test-Path "package.json")) {
    Write-Host "[ERROR] package.json not found. Wrong folder." -ForegroundColor Red
    exit
}

# Make vendors/[id] folder
$dir = "app/vendors/[id]"
if (-not (Test-Path $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

# Path to vendor page
$page = "app/vendors/[id]/page.tsx"

# Backup old
if (Test-Path $page) {
    Copy-Item $page "$page.bak-phase137" -Force
}

# Write new placeholder line-by-line
"" | Out-File $page -Encoding UTF8
Add-Content $page 'import Link from "next/link";'
Add-Content $page ""
Add-Content $page "export default function VendorPlaceholder({ params }) {"
Add-Content $page "  return ("
Add-Content $page "    <main className=""max-w-4xl mx-auto py-12"">"
Add-Content $page "      <h1 className=""text-3xl font-semibold mb-4"">Vendor profile coming soon</h1>"
Add-Content $page "      <p className=""text-slate-300 mb-6"">Vendor #{params.id} details will appear here soon.</p>"
Add-Content $page "      <Link href=""/vendors"" className=""text-sky-400 hover:text-sky-300"">Back to Vendors</Link>"
Add-Content $page "    </main>"
Add-Content $page "  );"
Add-Content $page "}"
Write-Host "[OK] Vendor placeholder page written." -ForegroundColor Green

# Clean .next
if (Test-Path ".next") {
    Remove-Item ".next" -Force -Recurse -ErrorAction SilentlyContinue
}

# Build
Write-Host "[INFO] Running build..." -ForegroundColor Cyan

if (Test-Path "pnpm-lock.yaml") { pnpm run build }
elseif (Test-Path "yarn.lock") { yarn build }
else { npm run build }

Write-Host "[OK] Build completed." -ForegroundColor Green

# Deploy (source)
Write-Host "[INFO] Deploying to Vercel..." -ForegroundColor Cyan
vercel deploy --prod --yes

Write-Host ""
Write-Host "=== Phase137 Completed ===" -ForegroundColor Green
