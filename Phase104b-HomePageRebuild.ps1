# Rebuild a functional, branded Home page (/) with safe client KPIs.
# Minimal and robust: no dynamic imports, no JSON flags Vercel doesn't support on Windows.

$ErrorActionPreference = 'Stop'
Set-Location "C:\Users\MR.NELSON\Downloads\truvern"

function Write-UTF8($Path, $Content) {
  $dir = Split-Path $Path -Parent
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  [IO.File]::WriteAllText($Path, $Content, [Text.UTF8Encoding]::new($false))
  Write-Host "Wrote: $Path"
}

# ---- locate app ----
$app = Join-Path (Get-Location) 'app'
if (-not (Test-Path $app)) { $app = Join-Path (Get-Location) 'apps\tprm\app' }
if (-not (Test-Path $app)) { throw "No Next.js app dir at .\app or .\apps\tprm\app" }

# ---- Tailwind baseline ----
pnpm add -D tailwindcss postcss autoprefixer | Out-Null

Write-UTF8 (Join-Path (Get-Location) 'tailwind.config.js') @"
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ['./app/**/*.{ts,tsx}','./components/**/*.{ts,tsx}'],
  theme: { extend: {} },
  plugins: [],
};
"@

Write-UTF8 (Join-Path (Get-Location) 'postcss.config.js') @"
module.exports = { plugins: { tailwindcss: {}, autoprefixer: {} } };
"@

Write-UTF8 (Join-Path $app 'globals.css') @'
@tailwind base;
@tailwind components;
@tailwind utilities;

/* Truvern base tokens */
:root { color-scheme: light; }
body  { background:#fff; color:#0b1220; }
.container { max-width: 1100px; margin: 0 auto; padding: 24px; }
a { text-decoration: none; }
'@

# ---- Chrome (header/nav/footer) ----
Write-UTF8 (Join-Path $app 'components\SiteChrome.tsx') @'
"use client";
import Link from "next/link";
import React from "react";

export default function SiteChrome({ children }: { children: React.ReactNode }) {
  return (
    <>
      <header className="border-b bg-white">
        <div className="container flex items-center justify-between">
          <Link href="/" className="font-semibold text-lg">Truvern</Link>
          <nav className="hidden md:flex gap-5 text-sm text-zinc-700">
            <Link href="/">Home</Link>
            <Link href="/trust-network">Trust Network</Link>
            <Link href="/vendors">Vendors</Link>
            <Link href="/pricing">Pricing</Link>
            <Link href="/contact">Contact</Link>
            <Link href="/login">Login</Link>
            <Link href="/subscribe" className="px-3 py-1 rounded bg-blue-600 text-white">Get Started</Link>
          </nav>
        </div>
      </header>

      <main className="container">{children}</main>

      <footer className="border-t mt-12">
        <div className="container py-6 text-xs text-zinc-500">
          © {new Date().getFullYear()} Truvern · Vendor Trust Network
        </div>
      </footer>
    </>
  );
}
'@

# ---- Layout wraps everything in SiteChrome ----
Write-UTF8 (Join-Path $app 'layout.tsx') @'
import "./globals.css";
import type { Metadata } from "next";
import React from "react";
import SiteChrome from "./components/SiteChrome";

export const metadata: Metadata = {
  title: "Truvern — Vendor Trust Network",
  description: "Assess, compare, and continuously monitor third-party vendors.",
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
'@

# ---- Home (client KPIs) ----
Write-UTF8 (Join-Path $app 'home-safe\HomeClient.tsx') @'
"use client";
import React from "react";

type Vendor = { id?: string | number; name?: string };
type Board = { generatedAt?: string; vendors?: Vendor[] };

async function loadJSON<T>(url: string): Promise<T | null> {
  try {
    const res = await fetch(url, { cache: "no-store" });
    if (!res.ok) return null;
    return await res.json();
  } catch { return null; }
}

export default function HomeClient() {
  const [vendors, setVendors] = React.useState<Vendor[]>([]);
  const [board, setBoard]     = React.useState<Board | null>(null);
  const [loading, setLoading] = React.useState(true);

  React.useEffect(() => {
    let alive = true;
    (async () => {
      const v = await loadJSON<any>("/api/vendors");
      const b = await loadJSON<Board>("/api/board");
      if (!alive) return;
      const list = Array.isArray(v?.vendors) ? v.vendors : (Array.isArray(v) ? v : []);
      setVendors(list ?? []);
      setBoard(b ?? null);
      setLoading(false);
    })();
    return () => { alive = false; };
  }, []);

  const vendorCount = vendors.length;

  return (
    <div>
      <section className="py-6">
        <h1 className="text-3xl font-bold">Trust your vendors.</h1>
        <p className="text-zinc-600 mt-2">Move faster with confidence.</p>
      </section>

      <section className="border rounded-xl p-4 flex items-center gap-4 mb-6">
        <div className="font-medium">KPI</div>
        <div className="px-3 py-1 border rounded-full font-mono">{vendorCount}</div>
        <div className="text-zinc-500 text-sm">vendors</div>
        {board?.generatedAt && (
          <div className="ml-auto text-xs text-zinc-500">
            generated {new Date(board.generatedAt).toLocaleString()}
          </div>
        )}
      </section>

      <div className="grid sm:grid-cols-2 gap-4">
        <a href="/trust-network" className="border rounded-lg p-4 hover:bg-zinc-50">
          <div className="font-semibold">Open Trust Network</div>
          <div className="text-sm text-zinc-600">Browse and compare vendors</div>
        </a>
        <a href="/reports/board" className="border rounded-lg p-4 hover:bg-zinc-50">
          <div className="font-semibold">Open Board Report</div>
          <div className="text-sm text-zinc-600">Summary, trends, KPIs</div>
        </a>
      </div>

      {loading ? (
        <div className="mt-6 text-sm text-zinc-500">Loading…</div>
      ) : vendorCount === 0 ? (
        <div className="mt-6 text-sm text-zinc-500">No vendors yet.</div>
      ) : (
        <div className="mt-6">
          <div className="text-sm text-zinc-500 mb-2">Example vendors</div>
          <ul className="list-disc pl-6">
            {vendors.slice(0,6).map((v, i) => (
              <li key={String(v?.id ?? i)}>{v?.name ?? "Vendor"}</li>
            ))}
          </ul>
        </div>
      )}
    </div>
  );
}
'@

# ---- Server page that renders the client component ----
Write-UTF8 (Join-Path $app 'page.tsx') @'
import HomeClient from "./home-safe/HomeClient";
export default function Page() { return <HomeClient />; }
'@

# ---- build & deploy ----
pnpm install
pnpm build

$deployOut = vercel --prod --yes
$deployed  = ($deployOut | Select-String -Pattern '\S+\.vercel\.app' -AllMatches).Matches.Value | Select-Object -Last 1
if (-not $deployed) {
  $deployed = (vercel ls --prod | Select-String -Pattern '\S+\.vercel\.app' -AllMatches).Matches.Value | Select-Object -First 1
}
if (-not $deployed) { throw "Could not determine deployed URL." }

vercel alias set $deployed truvern.com      | Out-Null
vercel alias set $deployed www.truvern.com  | Out-Null
Write-Host ("Aliased truvern.com -> {0}" -f $deployed) -ForegroundColor Green

# ---- verify ----
$base = "https://truvern.com"
foreach($u in @("$base/","$base/trust-network","$base/vendors","$base/pricing","$base/api/trust-network")){
  try {
    $r = Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 20
    Write-Host ("OK {0} -> HTTP {1}" -f $u,$r.StatusCode) -ForegroundColor Green
  } catch {
    $c = $_.Exception.Response.StatusCode.value__ 2>$null
    if ($c) { Write-Host ("WARN {0} -> HTTP {1}" -f $u,$c) -ForegroundColor DarkYellow }
    else    { Write-Host ("FAIL {0} -> {1}" -f $u,$_.Exception.Message) -ForegroundColor Red }
  }
}
