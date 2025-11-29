<# ===============================================================
 Phase155-BuildRouteRepair.ps1
 Fix:
 1) Remove backup route app/trust-network.__bak__ from compilation
 2) Ensure /legal/privacy has a valid page.tsx
 3) Clean caches, rebuild, and (optionally) deploy prebuilt to prod
 =============================================================== #>

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Safety: don’t run from system32
if ((Get-Location).Path -match '\\Windows\\System32$') {
    Write-Host "Please cd into your project folder (e.g. C:\Users\MR.NELSON\Downloads\truvern)" -ForegroundColor Red
    exit 1
}

$root = $pwd.Path
$ts   = Get-Date -Format 'yyyyMMdd-HHmmss'
$patchDir = Join-Path $root ("patch_backups\phase155-" + $ts)

New-Item -ItemType Directory -Force -Path $patchDir | Out-Null

function BackupPath {
    param([string]$PathToBackup)
    if (Test-Path $PathToBackup) {
        $leaf = Split-Path $PathToBackup -Leaf
        $dest = Join-Path $patchDir $leaf
        Copy-Item $PathToBackup $dest -Recurse -Force
        Write-Host ("Backup -> " + $dest)
    }
}

Write-Host "=== Phase155: Build Route Repair ===" -ForegroundColor Cyan

# -----------------------------------------------------------
# 1) Remove/relocate backup route: app/trust-network.__bak__
# -----------------------------------------------------------

$trustBak = Join-Path $root 'app\trust-network.__bak__'

if (Test-Path $trustBak) {
    Write-Host "Found backup route folder: app\trust-network.__bak__" -ForegroundColor Yellow
    BackupPath $trustBak
    # Move it out of the app tree so Next.js ignores it
    $newLocation = Join-Path $patchDir 'trust-network.__bak__'
    Move-Item $trustBak $newLocation -Force
    Write-Host ("Moved backup route to: " + $newLocation)
} else {
    Write-Host "No app\trust-network.__bak__ folder found (nothing to remove)."
}

# -----------------------------------------------------------
# 2) Ensure /legal/privacy has a valid page.tsx
# -----------------------------------------------------------

$legalDir    = Join-Path $root 'app\legal'
$privacyDir  = Join-Path $legalDir 'privacy'
$privacyPage = Join-Path $privacyDir 'page.tsx'

New-Item -ItemType Directory -Force -Path $privacyDir | Out-Null

if (Test-Path $privacyPage) {
    BackupPath $privacyPage
    Write-Host "app/legal/privacy/page.tsx already exists (backup saved)."
} else {
    Write-Host "Creating app/legal/privacy/page.tsx for /legal/privacy route."
@'
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Privacy Policy",
  description: "Truvern privacy policy and data protection overview.",
  alternates: { canonical: "/legal/privacy" },
  openGraph: {
    title: "Truvern Privacy Policy",
    description: "Learn how Truvern handles and protects your data.",
    images: ["/opengraph-image.png"],
  },
  icons: { icon: "/favicon.ico" },
};

export default function PrivacyPage() {
  return (
    <main className="mx-auto max-w-3xl px-6 py-10">
      <h1 className="text-2xl font-semibold mb-4">Privacy Policy</h1>
      <p className="text-sm opacity-80">
        This is a placeholder for the Truvern privacy policy page. You can
        replace this content with your full legal copy at any time.
      </p>
    </main>
  );
}
'@ | Set-Content -Path $privacyPage -Encoding UTF8
}

# -----------------------------------------------------------
# 3) Clean caches and rebuild
# -----------------------------------------------------------

Write-Host "`nCleaning .next and .vercel/output..." -ForegroundColor Yellow
if (Test-Path ".next") { Remove-Item ".next" -Recurse -Force }
if (Test-Path ".vercel\output") { Remove-Item ".vercel\output" -Recurse -Force }

# Package manager build
if (Get-Command pnpm -ErrorAction SilentlyContinue) {
    Write-Host "Running pnpm install + pnpm run build..." -ForegroundColor Yellow
    pnpm install --frozen-lockfile
    pnpm run build
} elseif (Get-Command npm -ErrorAction SilentlyContinue) {
    Write-Host "Running npm ci + npm run build..." -ForegroundColor Yellow
    npm ci
    npm run build
} elseif (Get-Command yarn -ErrorAction SilentlyContinue) {
    Write-Host "Running yarn install + yarn build..." -ForegroundColor Yellow
    yarn install --frozen-lockfile
    yarn build
} else {
    Write-Host "No pnpm/npm/yarn found; skipping local build." -ForegroundColor Red
}

# -----------------------------------------------------------
# 4) Optional: vercel prebuilt deploy (same pattern you used)
# -----------------------------------------------------------

if (Get-Command vercel -ErrorAction SilentlyContinue) {
    Write-Host "`nRunning vercel build + vercel deploy --prebuilt --prod..." -ForegroundColor Yellow
    vercel build
    vercel deploy --prebuilt --prod
} else {
    Write-Host "Vercel CLI not found; skipping deploy step." -ForegroundColor Yellow
}

Write-Host "`nPhase155 complete." -ForegroundColor Green
