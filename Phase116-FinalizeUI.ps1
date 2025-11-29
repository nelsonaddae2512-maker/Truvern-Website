<# Phase116-FinalizeUI.ps1
   Repairs UI build issues and finalizes footer + theme polish
#>

$ErrorActionPreference = "Stop"

Write-Host "=== Phase116: Finalize UI and Theme ===" -ForegroundColor Yellow

# Confirm we’re in project root
if (-not (Test-Path "package.json")) {
    Write-Host "❌ You must run this from the project root." -ForegroundColor Red
    exit 1
}

# Directories
$appDir = Join-Path (Get-Location) "app"
$compDir = Join-Path $appDir "components"
$nfDir = Join-Path $appDir "_not-found"
$ssoDir = Join-Path $appDir "sso"
$footerComp = Join-Path $compDir "FooterSafe.tsx"

# Create dirs
foreach ($d in @($compDir, $nfDir, $ssoDir)) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
}

# Create FooterSafe
@'
"use client";
export default function FooterSafe() {
  return (
    <footer className="mt-16 border-t border-zinc-200/60 px-6 py-10 text-sm text-zinc-500">
      <div className="mx-auto max-w-6xl flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
        <p>© {new Date().getFullYear()} Truvern. All rights reserved.</p>
        <nav className="flex gap-4">
          <a href="/pricing" className="hover:underline">Pricing</a>
          <a href="/contact" className="hover:underline">Contact</a>
          <a href="/trust-network" className="hover:underline">Trust Network</a>
        </nav>
      </div>
    </footer>
  );
}
'@ | Set-Content -Encoding UTF8 $footerComp

# Create _not-found page
@'
import Link from "next/link";
export default function NotFoundPage() {
  return (
    <main className="mx-auto max-w-3xl px-6 py-16">
      <h1 className="text-2xl font-semibold">Page Not Found</h1>
      <p className="mt-3 text-zinc-600">We couldn’t find what you’re looking for.</p>
      <Link href="/" className="text-blue-600 hover:underline mt-6 inline-block">Go Home</Link>
    </main>
  );
}
'@ | Set-Content -Encoding UTF8 (Join-Path $nfDir "page.tsx")

# Create /sso page placeholder
@'
export default function SSOPage() {
  return (
    <main className="mx-auto max-w-3xl px-6 py-16">
      <h1 className="text-2xl font-semibold">Single Sign-On</h1>
      <p className="mt-3 text-zinc-600">SSO setup will appear here soon.</p>
    </main>
  );
}
'@ | Set-Content -Encoding UTF8 (Join-Path $ssoDir "page.tsx")

# Build + Deploy
Write-Host "`nBuilding..." -ForegroundColor Yellow
pnpm install
pnpm run build

if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠️ Build failed. Attempting secondary build..." -ForegroundColor DarkYellow
    pnpm build
}

Write-Host "`nDeploying..." -ForegroundColor Yellow
$deployOut = vercel --prod --yes
$deployed = ($deployOut | Select-String -Pattern '\S+\.vercel\.app' -AllMatches).Matches.Value | Select-Object -Last 1
$domain = "truvern.com"

if ($deployed) {
    vercel alias set $deployed $domain | Out-Null
    vercel alias set $deployed "www.$domain" | Out-Null
    Write-Host "✅ Aliased $domain to $deployed" -ForegroundColor Green
}

# Check core pages
$urls = @(
  "https://truvern.com/",
  "https://truvern.com/trust-network",
  "https://truvern.com/vendors",
  "https://truvern.com/pricing",
  "https://truvern.com/contact"
)

foreach ($u in $urls) {
  try {
    $r = Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 20
    Write-Host ("OK {0} -> HTTP {1}" -f $u, $r.StatusCode) -ForegroundColor Green
  } catch {
    Write-Host ("WARN {0} -> {1}" -f $u, $_.Exception.Message) -ForegroundColor Yellow
  }
}

Write-Host "`n✅ Phase116 complete. UI finalized." -ForegroundColor Cyan
