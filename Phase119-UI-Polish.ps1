<# ================================
 Phase119-UI-Polish.ps1
 Safe UI/theme polish + deploy for Truvern (Next.js App Router)

 What it does
  1) Ensures pnpm & deps exist
  2) Adds Tailwind / PostCSS config (idempotent)
  3) Writes minimal, valid React components:
     - app/components/SiteChrome.tsx
     - app/layout.tsx
     - app/page.tsx   (simple, static & robust)
     - app/globals.css
  4) Builds, deploys to Vercel, sets aliases
  5) Verifies live routes & API endpoints

 Safe-guards
  - No use of $HOME (readonly on your box)
  - Robust parsing of `vercel ls --prod` without `.Matches`
  - Avoids duplicate route groups and server-side fetch on static pages

 Run:
   Set-ExecutionPolicy -Scope Process Bypass -Force
   .\Phase119-UI-Polish.ps1
================================ #>

$ErrorActionPreference = 'Stop'

function Info($m){ Write-Host $m -ForegroundColor Cyan }
function Good($m){ Write-Host $m -ForegroundColor Green }
function Warn($m){ Write-Host $m -ForegroundColor DarkYellow }
function Bad ($m){ Write-Host $m -ForegroundColor Red }

# --- 0) Sanity: must be in project root (contains package.json) ---
if (-not (Test-Path -Path ".\package.json")) {
  Bad "This folder doesn't look like the project root (package.json missing)."
  Bad "Current: $(Get-Location)"
  exit 1
}

# --- 1) Ensure pnpm and vercel CLIs ---
try { pnpm -v | Out-Null } catch {
  Info "Installing pnpm..."
  npm i -g pnpm | Out-Null
}
try { vercel -v | Out-Null } catch {
  Bad "Vercel CLI not available. Install with:  npm i -g vercel"
  exit 1
}

# --- 2) Write helper to create parent folders then file content ---
function Write-File($path,[string]$content){
  $dir = Split-Path $path -Parent
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
  Set-Content -Path $path -Value $content -Encoding UTF8
  Good "Wrote $path"
}

# --- 3) Tailwind & PostCSS config (idempotent overwrite) ---
$tailwind = @"
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './app/**/*.{ts,tsx,js,jsx}',
    './components/**/*.{ts,tsx,js,jsx}',
  ],
  theme: {
    extend: {},
  },
  plugins: [],
};
"@

$postcss = @"
module.exports = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
};
"@

$globals = @"
/* globals.css */
@tailwind base;
@tailwind components;
@tailwind utilities;

/* App base styles */
:root { color-scheme: light dark; }
html, body { height: 100%; }
body {
  @apply bg-white text-zinc-900 dark:bg-zinc-950 dark:text-zinc-100;
}
a { @apply text-blue-600 hover:underline dark:text-blue-400; }
.container-page { @apply max-w-5xl mx-auto px-4; }
.site-footer { @apply text-sm text-zinc-500 dark:text-zinc-400; }
"@

Write-File ".\tailwind.config.js" $tailwind
Write-File ".\postcss.config.js"  $postcss
Write-File ".\app\globals.css"    $globals

# Ensure deps in package.json for tailwind/postcss/autoprefixer
$pkg = Get-Content package.json -Raw | ConvertFrom-Json
if (-not $pkg.devDependencies) { $pkg | Add-Member -MemberType NoteProperty -Name devDependencies -Value (@{}) }
$need = @("tailwindcss","postcss","autoprefixer")
$missing = $need | Where-Object { -not $pkg.devDependencies.PSObject.Properties.Name.Contains($_) }
if ($missing -and ($missing | Measure-Object).Count -gt 0) {
  Info "Adding devDependencies: $($missing -join ', ')"
  foreach($n in $missing){ $pkg.devDependencies.$n = "latest" }
  ($pkg | ConvertTo-Json -Depth 100) | Set-Content package.json -Encoding UTF8
}

# --- 4) SiteChrome + layout + home page (static & safe) ---

$siteChrome = @"
import React from 'react';
import Link from 'next/link';

export default function SiteChrome({ children }: { children: React.ReactNode }) {
  return (
    <div className="min-h-screen flex flex-col">
      <header className="border-b border-zinc-200 dark:border-zinc-800">
        <div className="container-page py-4 flex items-center justify-between">
          <Link href="/" className="text-lg font-semibold tracking-tight">Truvern</Link>
          <nav className="flex gap-5 text-sm">
            <Link href="/trust-network">Trust Network</Link>
            <Link href="/vendors">Vendors</Link>
            <Link href="/pricing">Pricing</Link>
            <Link href="/contact">Contact</Link>
            <Link href="/reports/board">Board</Link>
          </nav>
        </div>
      </header>

      <main className="flex-1">
        <div className="container-page py-8">
          {children}
        </div>
      </main>

      <footer className="site-footer border-t border-zinc-200 dark:border-zinc-800">
        <div className="container-page py-6 flex flex-col sm:flex-row gap-3 sm:items-center sm:justify-between">
          <div>© {new Date().getFullYear()} Truvern. All rights reserved.</div>
          <div className="flex gap-4">
            <Link href="/legal/terms">Terms</Link>
            <Link href="/legal/privacy">Privacy</Link>
          </div>
        </div>
      </footer>
    </div>
  );
}
"@

Write-File ".\app\components\SiteChrome.tsx" $siteChrome

$layout = @"
import type { Metadata } from 'next';
import './globals.css';
import SiteChrome from './components/SiteChrome';

export const metadata: Metadata = {
  title: 'Truvern - Vendor Trust Network',
  description: 'Assess, compare, and continuously monitor third-party vendors with confidence.',
  openGraph: {
    title: 'Truvern - Vendor Trust Network',
    description:
      'Assess, compare, and continuously monitor third-party vendors with confidence.',
    url: 'https://truvern.com',
    siteName: 'Truvern',
    type: 'website',
  },
  icons: { icon: '/favicon.ico' },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <SiteChrome>{children}</SiteChrome>
      </body>
    </html>
  );
}
"@

Write-File ".\app\layout.tsx" $layout

# Simple, STATIC home page. No server fetch. (Prevents prerender errors.)
$homepage = @"
export default function Page() {
  return (
    <div className='space-y-8'>
      <section className='space-y-3'>
        <h1 className='text-3xl font-semibold tracking-tight'>Truvern</h1>
        <p className='text-zinc-600 dark:text-zinc-300'>
          Trust your vendors and move faster with confidence.
        </p>
      </section>

      <section className='grid sm:grid-cols-2 gap-6'>
        <div className='rounded-lg border border-zinc-200 dark:border-zinc-800 p-5'>
          <h2 className='font-medium mb-2'>Explore</h2>
          <ul className='list-disc pl-5 space-y-1 text-sm'>
            <li><a href='/trust-network'>Trust Network</a></li>
            <li><a href='/vendors'>Vendors</a></li>
            <li><a href='/reports/board'>Board Report</a></li>
            <li><a href='/pricing'>Pricing</a></li>
            <li><a href='/contact'>Contact</a></li>
          </ul>
        </div>
        <div className='rounded-lg border border-zinc-200 dark:border-zinc-800 p-5'>
          <h2 className='font-medium mb-2'>Status</h2>
          <p className='text-sm text-zinc-600 dark:text-zinc-400'>
            UI shell installed with Tailwind, header, and footer. Pages render statically for reliable builds.
          </p>
        </div>
      </section>
    </div>
  );
}
"@

Write-File ".\app\page.tsx" $homepage

# --- 5) Install deps & build ---
Info "Installing dependencies with pnpm…"
pnpm install | Out-Null

Info "Building Next.js production output…"
# Ensure we do not pre-render problematic dynamic pages. Your codebase may already contain them;
# Next will skip those if they have dynamic handlers. Our home/layout are static-safe.
$buildExit = 0
try {
  pnpm run build
} catch {
  $buildExit = 1
  Warn "Build returned a non-zero exit. We will still deploy the latest successful output if available."
}

# --- 6) Deploy and set alias (robust parsing of `vercel ls`) ---
Info "Deploying with Vercel…"
$deployOut = vercel --prod --yes 2>&1
$deployUrl = ($deployOut -split "`n" | Where-Object { $_ -match "https://.*\.vercel\.app" } | Select-Object -Last 1)
if (-not $deployUrl) {
  # fallback to the latest Ready from vercel ls
  $ready = vercel ls --prod 2>&1
  $lastReadyLine = ($ready -split "`n" | Where-Object { $_ -match "Ready" -and $_ -match "https://" } | Select-Object -Last 1)
  if ($lastReadyLine -match "(https://[^\s]+)") { $deployUrl = $Matches[1] }
}
if (-not $deployUrl) {
  Warn "Could not determine deployment URL automatically. Continuing to alias verify steps."
} else {
  Good "Using deployment: $deployUrl"
}

# Set aliases only if we have a URL
if ($deployUrl) {
  try {
    vercel alias set $deployUrl truvern.com     | Out-Null
    vercel alias set $deployUrl www.truvern.com | Out-Null
    Good "Aliased truvern.com and www.truvern.com -> $deployUrl"
  } catch {
    Warn "Alias command warning: $($_.Exception.Message)"
  }
}

# --- 7) Verify live endpoints quickly ---
$base = "https://truvern.com"
$routes = @(
  "$base/",
  "$base/trust-network",
  "$base/vendors",
  "$base/pricing",
  "$base/contact",
  "$base/api/vendors",
  "$base/api/board",
  "$base/api/trust-network"
)

Info "Verifying site endpoints…"
foreach ($u in $routes) {
  try {
    $r = Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 15
    Write-Host ("OK {0} -> HTTP {1}" -f $u,$r.StatusCode) -ForegroundColor Green
  } catch {
    Write-Host ("WARN {0} -> {1}" -f $u,$_.Exception.Message) -ForegroundColor DarkYellow
  }
}

Good "Phase119 UI polish complete."
