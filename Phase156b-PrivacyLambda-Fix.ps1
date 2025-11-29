<# ===============================================================
 Phase156b-PrivacyLambda-Fix.ps1
 Purpose:
   - Fix "Unable to find lambda for route: /legal/privacy"
   - Use a classic pages/ route for /legal/privacy
 =============================================================== #>

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Safety: avoid running from system32
if ((Get-Location).Path -match '\\Windows\\System32$') {
    Write-Host "Please cd into your project folder (e.g. C:\Users\MR.NELSON\Downloads\truvern)" -ForegroundColor Red
    exit 1
}

$root = $PWD.Path
$ts   = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupDir = Join-Path $root ("patch_backups\phase156b-" + $ts)
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null

function BackupPath {
    param([string]$PathToBackup)
    if (Test-Path $PathToBackup) {
        $leaf = Split-Path $PathToBackup -Leaf
        $dest = Join-Path $backupDir $leaf
        Copy-Item $PathToBackup $dest -Recurse -Force
        Write-Host ("Backup -> " + $dest)
    }
}

Write-Host "=== Phase156b: Privacy Lambda Fix ===" -ForegroundColor Cyan

# -----------------------------------------------------------
# 1) Remove App Router version of /legal/privacy if present
# -----------------------------------------------------------

$appPrivacyDir  = Join-Path $root 'app\legal\privacy'

if (Test-Path $appPrivacyDir) {
    Write-Host "Found App Router privacy route (app\\legal\\privacy) – backing up and removing." -ForegroundColor Yellow
    BackupPath $appPrivacyDir
    Remove-Item $appPrivacyDir -Recurse -Force
} else {
    Write-Host "No app\\legal\\privacy folder found (ok)."
}

# -----------------------------------------------------------
# 2) Create Pages Router version: pages/legal/privacy.tsx
# -----------------------------------------------------------

$pagesDir      = Join-Path $root 'pages'
$pagesLegalDir = Join-Path $pagesDir 'legal'
$pagesPrivacy  = Join-Path $pagesLegalDir 'privacy.tsx'

if (-not (Test-Path $pagesDir))      { New-Item -ItemType Directory -Force -Path $pagesDir      | Out-Null }
if (-not (Test-Path $pagesLegalDir)) { New-Item -ItemType Directory -Force -Path $pagesLegalDir | Out-Null }

if (Test-Path $pagesPrivacy) {
    Write-Host "pages\\legal\\privacy.tsx already exists – backing up current version." -ForegroundColor Yellow
    BackupPath $pagesPrivacy
}

@'
import Head from "next/head";

export default function PrivacyPage() {
  const canonical = "https://truvern.com/legal/privacy";
  const ogImage = "/opengraph-image.png";

  return (
    <>
      <Head>
        <title>Privacy Policy | Truvern</title>
        <meta
          name="description"
          content="Truvern privacy policy and data protection overview."
        />
        <link rel="canonical" href={canonical} />
        <meta property="og:title" content="Truvern Privacy Policy" />
        <meta
          property="og:description"
          content="Learn how Truvern handles and protects your data."
        />
        <meta property="og:url" content={canonical} />
        <meta property="og:image" content={ogImage} />
      </Head>
      <main className="mx-auto max-w-3xl px-6 py-10">
        <h1 className="text-2xl font-semibold mb-4">Privacy Policy</h1>
        <p className="text-sm opacity-80">
          This is a placeholder for the Truvern privacy policy page. Replace
          this content with your full legal copy when ready.
        </p>
      </main>
    </>
  );
}
'@ | Set-Content -Path $pagesPrivacy -Encoding UTF8

Write-Host "Created pages\\legal\\privacy.tsx for /legal/privacy." -ForegroundColor Cyan

# -----------------------------------------------------------
# 3) Clean build artifacts
# -----------------------------------------------------------

Write-Host "`nCleaning .next and .vercel/output..." -ForegroundColor Yellow
if (Test-Path ".next")          { Remove-Item ".next" -Recurse -Force }
if (Test-Path ".vercel\output") { Remove-Item ".vercel\output" -Recurse -Force }

# -----------------------------------------------------------
# 4) Local Next.js build
# -----------------------------------------------------------

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
# 5) Prebuilt Vercel deploy (if CLI available)
# -----------------------------------------------------------

if (Get-Command vercel -ErrorAction SilentlyContinue) {
    Write-Host "`nRunning vercel build + vercel deploy --prebuilt --prod..." -ForegroundColor Yellow
    vercel build
    vercel deploy --prebuilt --prod
} else {
    Write-Host "Vercel CLI not found; skipping deploy step." -ForegroundColor Yellow
}

Write-Host "`nPhase156b complete." -ForegroundColor Green
