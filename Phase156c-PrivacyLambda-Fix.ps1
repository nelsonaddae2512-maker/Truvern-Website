<# ===============================================================
 Phase156c-PrivacyLambda-Fix.ps1
 Fixes "Unable to find lambda for route: /legal/privacy"
 Creates pages/legal/privacy.tsx safely
=============================================================== #>

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Safety check
if ((Get-Location).Path -match '\\Windows\\System32$') {
    Write-Host "Do not run from system32. Please CD into the truvern folder." -ForegroundColor Red
    exit 1
}

$root = $PWD.Path
$ts = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupDir = Join-Path $root ("patch_backups\\phase156c-" + $ts)
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null

function BackupItem {
    param([string]$p)
    if (Test-Path $p) {
        $leaf = Split-Path $p -Leaf
        $dest = Join-Path $backupDir $leaf
        Copy-Item $p $dest -Recurse -Force
        Write-Host ("Backup saved: " + $dest)
    }
}

Write-Host "=== Phase156c: Privacy Lambda Fix ===" -ForegroundColor Cyan
Write-Host ""

# -----------------------------------------------------------
# 1. Remove existing app/ route for /legal/privacy
# -----------------------------------------------------------

$appPrivacyDir = Join-Path $root "app\\legal\\privacy"

if (Test-Path $appPrivacyDir) {
    Write-Host "Found app\\legal\\privacy folder. Backing up and removing..." -ForegroundColor Yellow
    BackupItem $appPrivacyDir
    Remove-Item $appPrivacyDir -Recurse -Force
} else {
    Write-Host "No app legal privacy folder found. Continuing..."
}

# -----------------------------------------------------------
# 2. Ensure pages/legal/privacy.tsx exists
# -----------------------------------------------------------

$pagesDir = Join-Path $root "pages"
$legalDir = Join-Path $pagesDir "legal"
$privacyPage = Join-Path $legalDir "privacy.tsx"

if (-not (Test-Path $pagesDir)) { New-Item -ItemType Directory -Path $pagesDir -Force | Out-Null }
if (-not (Test-Path $legalDir)) { New-Item -ItemType Directory -Path $legalDir -Force | Out-Null }

if (Test-Path $privacyPage) {
    Write-Host "Existing pages\\legal\\privacy.tsx found. Backing up..." -ForegroundColor Yellow
    BackupItem $privacyPage
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
        <meta name="description" content="Truvern privacy policy and data protection overview." />
        <link rel="canonical" href={canonical} />

        <meta property="og:title" content="Truvern Privacy Policy" />
        <meta property="og:description" content="Learn how Truvern protects data." />
        <meta property="og:image" content={ogImage} />
        <meta property="og:url" content={canonical} />
      </Head>

      <main className="mx-auto max-w-3xl px-6 py-10">
        <h1 className="text-2xl font-semibold mb-4">Privacy Policy</h1>
        <p className="text-sm opacity-80">
          This is placeholder text for the upcoming Truvern privacy policy.
        </p>
      </main>
    </>
  );
}
'@ | Set-Content -Path $privacyPage -Encoding utf8

Write-Host "Created/updated pages legal privacy route." -ForegroundColor Cyan

# -----------------------------------------------------------
# 3. Clean build artifacts
# -----------------------------------------------------------

Write-Host "`nCleaning .next and .vercel/output..." -ForegroundColor Yellow
if (Test-Path ".next") { Remove-Item ".next" -Recurse -Force }
if (Test-Path ".vercel\\output") { Remove-Item ".vercel\\output" -Recurse -Force }

# -----------------------------------------------------------
# 4. Build project
# -----------------------------------------------------------

if (Get-Command pnpm -ErrorAction SilentlyContinue) {
    pnpm install --frozen-lockfile
    pnpm run build
} elseif (Get-Command npm -ErrorAction SilentlyContinue) {
    npm ci
    npm run build
} elseif (Get-Command yarn -ErrorAction SilentlyContinue) {
    yarn install --frozen-lockfile
    yarn build
} else {
    Write-Host "No pnpm, npm, or yarn found. Build skipped." -ForegroundColor Red
}

# -----------------------------------------------------------
# 5. Deploy (if Vercel CLI detected)
# -----------------------------------------------------------

if (Get-Command vercel -ErrorAction SilentlyContinue) {
    Write-Host "`nRunning vercel build and deploy..." -ForegroundColor Yellow
    vercel build
    vercel deploy --prebuilt --prod
} else {
    Write-Host "Vercel CLI not found. Deployment skipped." -ForegroundColor DarkYellow
}

Write-Host "`nPhase156c complete." -ForegroundColor Green
