# ======================================================================
# Phase108-FinalTheme.ps1
# Footer + theme polish + dark mode, then rebuild/deploy/alias/verify.
# Safe: UI files only (no DB/auth).
# ======================================================================
[CmdletBinding()]
param(
  [string]$Root   = (Get-Location).Path,
  [string]$Domain = "truvern.com"
)
$ErrorActionPreference = "Stop"

function W($Path, $Content) {
  $dir = Split-Path $Path -Parent
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  [IO.File]::WriteAllText($Path, $Content, [Text.UTF8Encoding]::new($false))
  Write-Host "Wrote: $Path" -ForegroundColor Cyan
}

# Ensure we’re in the project root (not system32)
Set-Location $Root

# ---- Locate Next.js app dir ----
$app = Join-Path (Get-Location) 'app'
if (-not (Test-Path $app)) { $app = Join-Path (Get-Location) 'apps\tprm\app' }
if (-not (Test-Path $app)) { throw "No Next.js app at .\app or .\apps\tprm\app" }

# ---- Tailwind baseline (safe to re-run) ----
pnpm add -D tailwindcss postcss autoprefixer | Out-Null

W (Join-Path $Root 'tailwind.config.js') "@
/** @type {import('tailwindcss').Config} */
module.exports = {
  darkMode: 'class',
  content: ['./app/**/*.{ts,tsx}','./components/**/*.{ts,tsx}'],
  theme: {
    container: { center: true, padding: '24px' },
    extend: {
      colors: {
        brand: {
          50:'#eef6ff',100:'#d9ebff',200:'#b8d9ff',300:'#8fc1ff',400:'#5da2ff',
          500:'#2b7dff',600:'#1f61db',700:'#184cb0',800:'#153f8f',900:'#143773'
        }
      },
      boxShadow:{ card:'0 6px 24px rgba(0,0,0,.06)'},
      borderRadius:{ xl:'14px' }
    }
  },
  plugins:[]
};
"

W (Join-Path $Root 'postcss.config.js') "module.exports = { plugins: { tailwindcss: {}, autoprefixer: {} } };"

# ---- Global styles (light/dark, typography, utilities) ----
W (Join-Path $app 'globals.css') '@
@tailwind base;
@tailwind components;
@tailwind utilities;

:root { --bg:#ffffff; --fg:#0b1220; --muted:#6b7280; }
.dark  { --bg:#0b1220; --fg:#f8fafc; --muted:#94a3b8; }

html, body { background:var(--bg); color:var(--fg); }

h1{@apply text-3xl md:text-4xl font-bold}
h2{@apply text-2xl font-semibold}
h3{@apply text-xl font-semibold}
p { @apply text-zinc-600 dark:text-zinc-400 }

.page   { @apply container max-w-6xl; }
.card   { @apply border rounded-xl bg-white dark:bg-zinc-900 shadow-card; }
.link   { @apply text-brand-700 hover:text-brand-800 dark:text-brand-300 dark:hover:text-brand-200 }
.btn    { @apply inline-flex items-center justify-center rounded-md px-4 py-2 font-medium }
.btn-primary { @apply btn bg-brand-600 text-white hover:bg-brand-700 }
.btn-ghost   { @apply btn bg-transparent text-brand-700 hover:bg-brand-50 dark:text-brand-300 dark:hover:bg-zinc-800 }
'@

# ---- Dark mode toggle (client) ----
$components = Join-Path $app 'components'
W (Join-Path $components 'DarkModeToggle.tsx') "@
'use client';
import React from 'react';

export default function DarkModeToggle(){
  const [mounted,setMounted] = React.useState(false);
  React.useEffect(()=>{ setMounted(true); },[]);
  React.useEffect(()=>{
    const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
    const saved = localStorage.getItem('theme');
    const enableDark = saved ? saved==='dark' : prefersDark;
    document.documentElement.classList.toggle('dark', enableDark);
  },[]);
  if(!mounted) return null;

  const onToggle = () => {
    const isDark = document.documentElement.classList.toggle('dark');
    localStorage.setItem('theme', isDark ? 'dark' : 'light');
  };

  return (
    <button onClick={onToggle} className="text-sm px-3 py-2 rounded border dark:border-zinc-700">
      Toggle {document.documentElement.classList.contains('dark') ? 'Light' : 'Dark'}
    </button>
  );
}
"

# ---- Site chrome with CLEAN FOOTER ----
W (Join-Path $components 'SiteChrome.tsx') "@
'use client';
import Link from 'next/link';
import React from 'react';
import DarkModeToggle from './DarkModeToggle';

export default function SiteChrome({ children }: { children: React.ReactNode }) {
  return (
    <>
      <header className='border-b bg-white dark:bg-zinc-950 sticky top-0 z-20'>
        <div className='page flex items-center justify-between h-16'>
          <Link href='/' className='font-semibold text-lg'>Truvern</Link>
          <nav className='hidden md:flex gap-6 text-sm text-zinc-700 dark:text-zinc-300'>
            <Link href='/' className='hover:text-brand-700 dark:hover:text-brand-300'>Home</Link>
            <Link href='/trust-network' className='hover:text-brand-700 dark:hover:text-brand-300'>Trust Network</Link>
            <Link href='/vendors' className='hover:text-brand-700 dark:hover:text-brand-300'>Vendors</Link>
            <Link href='/pricing' className='hover:text-brand-700 dark:hover:text-brand-300'>Pricing</Link>
            <Link href='/contact' className='hover:text-brand-700 dark:hover:text-brand-300'>Contact</Link>
          </nav>
          <div className='hidden md:flex gap-2 items-center'>
            <DarkModeToggle />
            <Link href='/login' className='btn-ghost'>Login</Link>
            <Link href='/subscribe' className='btn-primary'>Get Started</Link>
          </div>
          <div className='md:hidden text-sm text-zinc-500'>Menu</div>
        </div>
      </header>

      <main className='page py-8'>{children}</main>

      <footer className='border-t mt-12 bg-white dark:bg-zinc-950'>
        <div className='page py-8 grid gap-6 md:grid-cols-4 text-sm text-zinc-600 dark:text-zinc-400'>
          <div>
            <div className='font-semibold mb-2'>Truvern</div>
            <p>Vendor Trust Network for modern TPRM.</p>
          </div>
          <div>
            <div className='font-semibold mb-2'>Product</div>
            <ul className='space-y-1'>
              <li><Link className='link' href='/trust-network'>Trust Network</Link></li>
              <li><Link className='link' href='/vendors'>Vendors</Link></li>
              <li><Link className='link' href='/pricing'>Pricing</Link></li>
              <li><Link className='link' href='/reports/board'>Board Report</Link></li>
            </ul>
          </div>
          <div>
            <div className='font-semibold mb-2'>Company</div>
            <ul className='space-y-1'>
              <li><Link className='link' href='/legal/privacy'>Privacy</Link></li>
              <li><Link className='link' href='/legal/terms'>Terms</Link></li>
              <li><Link className='link' href='/contact'>Contact</Link></li>
            </ul>
          </div>
          <div>
            <div className='font-semibold mb-2'>Follow</div>
            <ul className='space-y-1'>
              <li><a className='link' href='https://x.com' target='_blank'>X (Twitter)</a></li>
              <li><a className='link' href='https://www.linkedin.com' target='_blank'>LinkedIn</a></li>
            </ul>
          </div>
        </div>
        <div className='page pb-8 text-xs text-zinc-400'>
          {'\u00A9'} {new Date().getFullYear()} Truvern · Vendor Trust Network
        </div>
      </footer>
    </>
  );
}
"

# ---- Layout keeps UTF-8 meta & uses SiteChrome ----
W (Join-Path $app 'layout.tsx') "@
import './globals.css';
import type { Metadata } from 'next';
import React from 'react';
import SiteChrome from './components/SiteChrome';

export const metadata: Metadata = {
  title: 'Truvern — Vendor Trust Network',
  description: 'Assess, compare, and continuously monitor third-party vendors.',
  openGraph: {
    title: 'Truvern — Vendor Trust Network',
    description: 'Assess, compare, and continuously monitor third-party vendors.',
    url: 'https://truvern.com',
    siteName: 'Truvern',
    type: 'website'
  }
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang='en'>
      <head><meta charSet='utf-8' /></head>
      <body><SiteChrome>{children}</SiteChrome></body>
    </html>
  );
}
"

# ---- Build & deploy ----
pnpm install
pnpm build

$deployOut = vercel --prod --yes
$deployed  = ($deployOut | Select-String -Pattern '\S+\.vercel\.app' -AllMatches).Matches.Value | Select-Object -Last 1
if (-not $deployed) {
  $deployed = (vercel ls --prod | Select-String -Pattern '\S+\.vercel\.app' -AllMatches).Matches.Value | Select-Object -First 1
}
if (-not $deployed) { throw "Could not determine deployed URL." }

vercel alias set $deployed $Domain          | Out-Null
vercel alias set $deployed ("www."+$Domain) | Out-Null
Write-Host ("Aliased {0} -> {1}" -f $Domain, $deployed) -ForegroundColor Green

# ---- Verify core pages quickly ----
$base = "https://$Domain"
[string[]]$urls = @("$base/","$base/trust-network","$base/vendors","$base/pricing","$base/contact")
foreach($u in $urls){
  try { $r = Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 20; Write-Host ("OK {0} -> HTTP {1}" -f $u,$r.StatusCode) -ForegroundColor Green }
  catch {
    $c = $_.Exception.Response.StatusCode.value__ 2>$null
    if ($c) { Write-Host ("WARN {0} -> HTTP {1}" -f $u,$c) -ForegroundColor DarkYellow } else { Write-Host ("FAIL {0} -> {1}" -f $u,$_.Exception.Message) -ForegroundColor Red }
  }
}
