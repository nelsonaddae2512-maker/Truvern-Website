# Final visual + encoding + data fetch polish for truvern.com
# - Enforce UTF-8 headers (next.config.js)
# - Replace raw © with \u00A9
# - Server-side KPIs (no stuck "Loading…")
# - Trust network rendered server-side
# - Build, deploy, alias, verify (and scan homepage for stray 'Â')

$ErrorActionPreference = 'Stop'
Set-Location "C:\Users\MR.NELSON\Downloads\truvern"

function WriteUtf8($Path,$Content){
  $dir = Split-Path $Path -Parent
  if(-not (Test-Path $dir)){ New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  [IO.File]::WriteAllText($Path,$Content,[Text.UTF8Encoding]::new($false))
  Write-Host "Wrote: $Path"
}

# ---- locate app ----
$app = Join-Path (Get-Location) 'app'
if(-not (Test-Path $app)){ $app = Join-Path (Get-Location) 'apps\tprm\app' }
if(-not (Test-Path $app)){ throw "No Next.js app directory at .\app or .\apps\tprm\app" }

# ---- 1) Enforce UTF-8 & sane headers ----
$nextCfg = Join-Path (Get-Location) 'next.config.js'
WriteUtf8 $nextCfg @"
/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  headers: async () => ([
    {
      source: '/:path*',
      headers: [
        { key: 'Content-Type', value: 'text/html; charset=utf-8' },
        { key: 'X-Content-Type-Options', value: 'nosniff' }
      ],
    },
  ]),
};
module.exports = nextConfig;
"@

# ---- 2) Footer: avoid raw © and ensure charset meta ----
$layout = Join-Path $app 'layout.tsx'
WriteUtf8 $layout @"
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
      <body>
        <SiteChrome>{children}</SiteChrome>
      </body>
    </html>
  );
}
"@

$chrome = Join-Path $app 'components\SiteChrome.tsx'
WriteUtf8 $chrome @"
'use client';
import Link from 'next/link';
import React from 'react';

export default function SiteChrome({ children }: { children: React.ReactNode }) {
  return (
    <>
      <header className='border-b bg-white sticky top-0 z-20'>
        <div className='container mx-auto max-w-6xl px-6 flex items-center justify-between h-16'>
          <Link href='/' className='font-semibold text-lg'>Truvern</Link>
          <nav className='hidden md:flex gap-6 text-sm text-zinc-700'>
            <Link href='/' className='hover:text-blue-700'>Home</Link>
            <Link href='/trust-network' className='hover:text-blue-700'>Trust Network</Link>
            <Link href='/vendors' className='hover:text-blue-700'>Vendors</Link>
            <Link href='/pricing' className='hover:text-blue-700'>Pricing</Link>
            <Link href='/contact' className='hover:text-blue-700'>Contact</Link>
          </nav>
          <div className='hidden md:flex gap-2'>
            <Link href='/login' className='px-3 py-2 text-sm'>Login</Link>
            <Link href='/subscribe' className='px-3 py-2 rounded bg-blue-600 text-white text-sm'>Get Started</Link>
          </div>
          <div className='md:hidden text-sm text-zinc-500'>Menu</div>
        </div>
      </header>

      <main className='container mx-auto max-w-6xl px-6 py-8'>{children}</main>

      <footer className='border-t mt-12 bg-white'>
        <div className='container mx-auto max-w-6xl px-6 py-8 grid gap-6 md:grid-cols-3 text-sm text-zinc-600'>
          <div>
            <div className='font-semibold mb-2'>Truvern</div>
            <p>Vendor Trust Network for modern TPRM.</p>
          </div>
          <div>
            <div className='font-semibold mb-2'>Product</div>
            <ul className='space-y-1'>
              <li><Link href='/trust-network'>Trust Network</Link></li>
              <li><Link href='/vendors'>Vendors</Link></li>
              <li><Link href='/pricing'>Pricing</Link></li>
              <li><Link href='/reports/board'>Board Report</Link></li>
            </ul>
          </div>
          <div>
            <div className='font-semibold mb-2'>Company</div>
            <ul className='space-y-1'>
              <li><Link href='/legal/privacy'>Privacy</Link></li>
              <li><Link href='/legal/terms'>Terms</Link></li>
              <li><Link href='/contact'>Contact</Link></li>
            </ul>
          </div>
        </div>
        <div className='container mx-auto max-w-6xl px-6 pb-8 text-xs text-zinc-400'>
          {'\u00A9'} {new Date().getFullYear()} Truvern · Vendor Trust Network
        </div>
      </footer>
    </>
  );
}
"@

# ---- 3) Server-side KPI for Home (no stuck Loading) ----
# Server wrapper fetches; minimal client for interactivity remains optional
$homeServer = Join-Path $app 'page.tsx'
WriteUtf8 $homeServer @"
import React from 'react';

async function getVendors() {
  try {
    const r = await fetch(`${process.env.NEXT_PUBLIC_SITE_URL ?? ''}/api/vendors`, { cache: 'no-store' });
    if (!r.ok) return [];
    const j = await r.json();
    return Array.isArray(j?.vendors) ? j.vendors : (Array.isArray(j) ? j : []);
  } catch { return []; }
}

async function getBoard() {
  try {
    const r = await fetch(`${process.env.NEXT_PUBLIC_SITE_URL ?? ''}/api/board`, { cache: 'no-store' });
    if (!r.ok) return null;
    return await r.json();
  } catch { return null; }
}

export default async function Page() {
  const [vendors, board] = await Promise.all([getVendors(), getBoard()]);
  const vendorCount = vendors.length;

  return (
    <div className='space-y-8'>
      <section className='rounded-2xl p-8 md:p-12 border bg-gradient-to-br from-blue-50 to-white'>
        <h1 className='text-3xl md:text-4xl font-bold'>Trust your vendors. Move faster with confidence.</h1>
        <p className='mt-2 max-w-2xl text-zinc-600'>
          Assess, compare, and continuously monitor third-party vendors with a shared trust profile.
        </p>
        <div className='mt-6 flex gap-3'>
          <a className='px-4 py-2 rounded bg-blue-600 text-white' href='/trust-network'>Open Trust Network</a>
          <a className='px-4 py-2 rounded border' href='/reports/board'>Open Board Report</a>
        </div>
      </section>

      <section className='border rounded-xl p-4 flex items-center gap-4 bg-white shadow-sm'>
        <div className='font-medium'>Vendors</div>
        <div className='px-3 py-1 border rounded-full font-mono'>{vendorCount}</div>
        <div className='text-zinc-500 text-sm'>total</div>
        {board?.generatedAt && (
          <div className='ml-auto text-xs text-zinc-500'>
            generated {new Date(board.generatedAt).toLocaleString()}
          </div>
        )}
      </section>

      {vendorCount > 0 && (
        <div>
          <h2 className='text-2xl font-semibold mb-3'>Example vendors</h2>
          <div className='grid sm:grid-cols-2 md:grid-cols-3 gap-3'>
            {vendors.slice(0,6).map((v: any, i: number) => (
              <div key={String(v?.id ?? i)} className='border rounded-xl p-4 bg-white shadow-sm'>
                {v?.name ?? 'Vendor'}
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
"@

# ---- 4) Trust Network page rendered server-side too ----
$tnPage = Join-Path $app 'trust-network\page.tsx'
WriteUtf8 $tnPage @"
export default async function TrustNetworkPage() {
  async function getItems(){
    try{
      const r = await fetch(`${process.env.NEXT_PUBLIC_SITE_URL ?? ''}/api/trust-network`, { cache: 'no-store' });
      if(!r.ok) return [];
      const j = await r.json();
      return Array.isArray(j?.vendors) ? j.vendors : [];
    }catch{ return []; }
  }
  const items = await getItems();

  return (
    <div>
      <h1 className='text-2xl font-bold mb-3'>Trust Network</h1>
      {items.length === 0 ? <div className='text-sm text-zinc-500'>No vendors yet.</div> : (
        <ul className='grid sm:grid-cols-2 md:grid-cols-3 gap-3'>
          {items.map((v:any,i:number)=>(
            <li key={String(v?.id ?? i)} className='border rounded-xl p-4 bg-white shadow-sm'>
              <div className='font-medium'>{v?.name ?? 'Vendor'}</div>
              {v?.score && <div className='text-xs text-zinc-500 mt-1'>Trust Score: {v.score}</div>}
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
"@

# Ensure NEXT_PUBLIC_SITE_URL is set for server fetch when needed (fallback to domain)
$envPath = Join-Path (Get-Location) '.env'
if (Test-Path $envPath) {
  $envContent = Get-Content $envPath -Raw
  if ($envContent -notmatch 'NEXT_PUBLIC_SITE_URL=') {
    Add-Content -Path $envPath -Value "`nNEXT_PUBLIC_SITE_URL=https://truvern.com"
    Write-Host "Added NEXT_PUBLIC_SITE_URL to .env"
  }
} else {
  WriteUtf8 $envPath "NEXT_PUBLIC_SITE_URL=https://truvern.com`n"
}

# ---- Build & deploy ----
pnpm install | Out-Null
pnpm build

$deployOut = vercel --prod --yes
$deployed  = ($deployOut | Select-String -Pattern '\S+\.vercel\.app' -AllMatches).Matches.Value | Select-Object -Last 1
if(-not $deployed){
  $deployed = (vercel ls --prod | Select-String -Pattern '\S+\.vercel\.app' -AllMatches).Matches.Value | Select-Object -First 1
}
if(-not $deployed){ throw "Could not determine deployed URL." }

vercel alias set $deployed truvern.com     | Out-Null
vercel alias set $deployed www.truvern.com | Out-Null
Write-Host ("Aliased truvern.com -> {0}" -f $deployed) -ForegroundColor Green

# ---- Verify + content sanity (and check for stray Â) ----
$base = "https://truvern.com"
$urls = @("$base/","$base/trust-network","$base/vendors","$base/pricing","$base/contact","$base/api/vendors","$base/api/board","$base/api/trust-network")
foreach($u in $urls){
  try { $r = Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 20; Write-Host ("OK {0} -> HTTP {1}" -f $u,$r.StatusCode) -ForegroundColor Green }
  catch {
    $c = $_.Exception.Response.StatusCode.value__ 2>$null
    if ($c) { Write-Host ("WARN {0} -> HTTP {1}" -f $u,$c) -ForegroundColor DarkYellow } else { Write-Host ("FAIL {0} -> {1}" -f $u,$_.Exception.Message) -ForegroundColor Red }
  }
}

# ---- Final UTF-8 validation (safe for PowerShell parser) ----
$homeResponse = Invoke-WebRequest $base -UseBasicParsing -TimeoutSec 20
$head = $homeResponse.Content.Substring(0, [Math]::Min(800, $homeResponse.Content.Length))

# Check for any stray UTF-8 artifacts (A-with-circumflex etc.)
$bad = [regex]::Matches($head, "[\u00C2\u00A0]").Count
if ($bad -gt 0) {
  Write-Host ("WARN: Found {0} stray UTF-8 artifacts (Â or NBSP) in first 800 chars." -f $bad) -ForegroundColor DarkYellow
} else {
  Write-Host "OK: No stray UTF-8 artifacts detected in first 800 chars." -ForegroundColor Green
}
