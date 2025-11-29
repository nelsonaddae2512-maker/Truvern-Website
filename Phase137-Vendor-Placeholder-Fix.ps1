<# =====================================================================
 Phase137-Vendor-Placeholder-Fix.ps1
 -----------------------------------------------------------------------
 Goal:
   • Replace /vendors/[id] with a safe, styled placeholder page
   • Prevent "Something went wrong" server component errors
   • Rebuild and deploy to Vercel (source deploy)
 ===================================================================== #>

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "=== Phase137 – Vendor Detail Safe Placeholder ===" -ForegroundColor Cyan
Write-Host ""

# Ensure we are in the project root (NOT System32)
if ($PWD.Path -match "System32") {
    Write-Host "[ERROR] Do NOT run from System32. cd into the project folder first." -ForegroundColor Red
    exit
}

if (-not (Test-Path "package.json")) {
    Write-Host "[ERROR] package.json not found. This is not the project root." -ForegroundColor Red
    exit
}

# Logs
if (-not (Test-Path ".\logs")) {
    New-Item -ItemType Directory -Path ".\logs" | Out-Null
}
$log = ".\logs\phase137-" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".log"
Start-Transcript -Path $log -Force | Out-Null
Write-Host "[INFO] Logging to $log" -ForegroundColor DarkYellow

# ---------------------------------------------------------------------
# 1. Write safe placeholder page for app/vendors/[id]/page.tsx
# ---------------------------------------------------------------------

Write-Host ""
Write-Host "[1/3] Writing safe placeholder for /vendors/[id] ..." -ForegroundColor Cyan

$vendorsDir = "app\vendors\[id]"
if (-not (Test-Path $vendorsDir)) {
    New-Item -ItemType Directory -Path $vendorsDir -Force | Out-Null
}

$pagePath = Join-Path $vendorsDir "page.tsx"

if (Test-Path $pagePath) {
    Copy-Item $pagePath "$pagePath.bak-phase137" -Force
    Write-Host "  Backup saved: $pagePath.bak-phase137" -ForegroundColor DarkYellow
}

@'
import Link from "next/link";

interface VendorPageProps {
  params: { id: string };
}

export default function VendorPlaceholderPage({ params }: VendorPageProps) {
  return (
    <main className="max-w-5xl mx-auto py-12">
      <p className="text-sm text-sky-400 mb-2">
        Truvern · Vendor #{params.id}
      </p>
      <h1 className="text-3xl font-semibold mb-4">Vendor profile coming soon</h1>
      <p className="text-slate-300 mb-6">
        This vendor detail view is part of an upcoming Truvern release.
        Your core dashboards, trust network, and board reports remain fully available.
      </p>
      <div className="flex gap-4">
        <Link href="/trust-network" className="text-sky-400 hover:text-sky-300">
          Back to Trust Network
        </Link>
        <Link href="/vendors" className="text-sky-400 hover:text-sky-300">
          Back to Vendors
        </Link>
      </div>
    </main>
  );
}
'@ | Set-Content -Path $pagePath -Encoding UTF8

Write-Host "[OK] /vendors/[id] now uses a safe placeholder page." -ForegroundColor Green

# ---------------------------------------------------------------------
# 2. Clean .next and rebuild
# ---------------------------------------------------------------------

Write-Host ""
Write-Host "[2/3] Cleaning .next and running build ..." -ForegroundColor Cyan

Remove-Item ".next" -Recurse -Force -ErrorAction SilentlyContinue

if (Test-Path "pnpm-lock.yaml") {
    pnpm run build
}
elseif (Test-Path "yarn.lock") {
    yarn build
}
else {
    npm run build
}

Write-Host "[OK] Build completed." -ForegroundColor Green

# ---------------------------------------------------------------------
# 3. Deploy source to Vercel (no --prebuilt)
# ---------------------------------------------------------------------

Write-Host ""
Write-Host "[3/3] Deploying to Vercel (source deploy) ..." -ForegroundColor Cyan

if (-not (Get-Command vercel -ErrorAction SilentlyContinue)) {
    Write-Host "[ERROR] vercel CLI missing. Install with: npm i -g vercel" -ForegroundColor Red
    Stop-Transcript | Out-Null
    exit
}

vercel deploy --prod --yes

Write-Host ""
Write-Host "=== Phase137 Completed ===" -ForegroundColor Green
Write-Host "Log: $log" -ForegroundColor DarkYellow

Stop-Transcript | Out-Null
