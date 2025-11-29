<# =============================================================================
 Phase144-ContentBootstrap.ps1
 Purpose: Populate Truvern.com with sensible content, nav, footer, and pages.
 Compatible: Windows PowerShell 5.x
 ============================================================================= #>

#region Safety & Setup
$ErrorActionPreference='Stop'
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12

if ((Get-Location).Path -match '\\Windows\\System32$') {
  Write-Host '❌ Do not run from system32. cd into your project folder (e.g., C:\Users\MR.NELSON\Downloads\truvern) and rerun.' -ForegroundColor Red
  exit 1
}

$root=$pwd.Path
$ts=Get-Date -Format 'yyyyMMdd-HHmmss'
$logs=Join-Path $root 'logs'
$backups=Join-Path $root ("patch_backups\phase144-" + $ts)
New-Item -ItemType Directory -Force -Path $logs,$backups | Out-Null
$logFile=Join-Path $logs ("Phase144-ContentBootstrap-" + $ts + ".log")
function Log { param([string]$m,[string]$lvl='INFO')
  $line='[{0}] [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),$lvl,$m
  $line | Tee-Object -FilePath $logFile -Append | Out-Null
}
Log '=== Phase144: Content Bootstrap ==='
#endregion

#region Paths
$appDir = Join-Path $root 'app'
$componentsDir = Join-Path $appDir 'components'
$vendorsDir = Join-Path $appDir 'vendors'
$reportsDir = Join-Path $appDir 'reports\board'
$trustDir = Join-Path $appDir 'trust-network'
$authLoginDir = Join-Path $appDir 'login'
$authSignupDir= Join-Path $appDir 'signup'
$dashboardDir = Join-Path $appDir 'dashboard'
$publicDir = Join-Path $root 'public'

$layoutTsx = Join-Path $appDir 'layout.tsx'
$layoutTs  = Join-Path $appDir 'layout.ts'
$layoutFile = if (Test-Path $layoutTsx) { $layoutTsx } elseif (Test-Path $layoutTs) { $layoutTs } else { $null }

New-Item -ItemType Directory -Force -Path $appDir,$componentsDir,$vendorsDir,$reportsDir,$trustDir,$authLoginDir,$authSignupDir,$dashboardDir,$publicDir | Out-Null
#endregion

#region Helpers
function Backup-IfExists { param([string]$p)
  if (Test-Path $p) {
    $dest = Join-Path $backups ((Split-Path $p -Leaf) + '.' + $ts + '.bak')
    Copy-Item $p $dest -Force
    Log ("Backup -> " + $dest)
  }
}
function Write-File { param([string]$p,[string]$content)
  Backup-IfExists $p
  $content | Out-File -FilePath $p -Encoding UTF8
  Log ("Wrote -> " + $p)
}
#endregion

#region Tailwind / globals.css minimal sanity
$globalsCss = Join-Path $appDir 'globals.css'
if (-not (Test-Path $globalsCss)) {
  @'
@tailwind base;
@tailwind components;
@tailwind utilities;

:root { --tv-bg: #0b1220; --tv-fg: #e6f0ff; --tv-accent:#22c55e; }
body { background: var(--tv-bg); color: var(--tv-fg); }
a { text-decoration: none; }
.container { max-width: 1200px; margin: 0 auto; padding: 1rem; }
.card { background: rgba(255,255,255,0.04); border: 1px solid rgba(255,255,255,0.08); border-radius: 14px; padding: 1rem; }
.btn { display:inline-block; padding:.6rem 1rem; border-radius:10px; border:1px solid rgba(255,255,255,0.14); }
.btn-primary { background: var(--tv-accent); color:#0b1220; border-color: transparent; }
.grid-3 { display:grid; grid-template-columns:repeat(3,minmax(0,1fr)); gap:1rem; }
@media (max-width: 900px){ .grid-3 { grid-template-columns:1fr; } }
'@ | Out-File -FilePath $globalsCss -Encoding UTF8
  Log 'Created minimal globals.css (Tailwind layers + utilities)'
}
#endregion

#region Navbar / Footer components (app/components)
$navbar = @'
"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";

export default function Navbar() {
  const pathname = usePathname();
  const LinkItem = ({ href, label }: { href: string; label: string }) => (
    <Link
      href={href}
      className={`px-3 py-2 rounded-lg hover:opacity-90 ${pathname===href ? "bg-white/10" : ""}`}
    >
      {label}
    </Link>
  );

  return (
    <header className="border-b border-white/10 sticky top-0 z-50 bg-black/30 backdrop-blur">
      <div className="container flex items-center justify-between">
        <Link href="/" className="font-semibold tracking-tight">Truvern</Link>
        <nav className="flex items-center gap-1">
          <LinkItem href="/" label="Home" />
          <LinkItem href="/trust-network" label="Trust Network" />
          <LinkItem href="/vendors" label="Vendors" />
          <LinkItem href="/reports/board" label="Board Report" />
        </nav>
        <div className="flex items-center gap-2">
          <Link href="/login" className="btn">Log in</Link>
          <Link href="/signup" className="btn btn-primary">Sign up</Link>
        </div>
      </div>
    </header>
  );
}
'@

$footer = @'
export default function Footer() {
  return (
    <footer className="mt-16 border-t border-white/10">
      <div className="container py-8 text-sm opacity-80 flex items-center justify-between">
        <span>© ' + (Get-Date).Year + ' Truvern — TPRM Trust Network</span>
        <div className="flex gap-4">
          <a href="/legal/privacy">Privacy</a>
          <a href="/security">Security</a>
          <a href="/docs">Docs</a>
        </div>
      </div>
    </footer>
  );
}
'@

Write-File (Join-Path $componentsDir 'Navbar.tsx') $navbar
Write-File (Join-Path $componentsDir 'Footer.tsx') $footer
#endregion

#region Layout patch (imports + metadata + structure)
if (-not $layoutFile) {
  $layoutFile = Join-Path $appDir 'layout.tsx'
}
$layoutContent = @'
import "./globals.css";
import type { Metadata } from "next";
import Navbar from "./components/Navbar";
import Footer from "./components/Footer";

export const metadata: Metadata = {
  metadataBase: new URL("https://truvern.com"),
  title: { default: "Truvern", template: "%s | Truvern" },
  description: "Truvern — Vendor Trust Network & TPRM platform for faster, verifiable risk reviews.",
  openGraph: { images: ["/opengraph-image.png"] },
  icons: { icon: "/favicon.ico" }
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <Navbar />
        <main className="container">{children}</main>
        <Footer />
      </body>
    </html>
  );
}
'@

if (Test-Path $layoutFile) {
  # merge if an export already exists: we’ll just overwrite to guarantee consistency (backup kept)
  Write-File $layoutFile $layoutContent
} else {
  Write-File $layoutFile $layoutContent
}
#endregion

#region Home page (app/page.tsx)
$home = @'
import Link from "next/link";

export default function Page() {
  return (
    <section className="mt-10">
      <div className="card">
        <h1 className="text-3xl font-semibold">Truvern Trust Network</h1>
        <p className="opacity-80 mt-2">
          A shared TPRM network to reuse vendor answers and speed up due diligence.
        </p>
        <div className="mt-4 flex gap-2">
          <Link href="/trust-network" className="btn btn-primary">Explore Trust Network</Link>
          <Link href="/vendors" className="btn">Browse Vendors</Link>
          <Link href="/reports/board" className="btn">Board Report</Link>
        </div>
      </div>

      <div className="grid-3 mt-8">
        <div className="card">
          <h2 className="font-semibold mb-2">Reusable Assessments</h2>
          <p className="opacity-80">Vendors answer once; customers reuse and verify.</p>
        </div>
        <div className="card">
          <h2 className="font-semibold mb-2">Evidence & Controls</h2>
          <p className="opacity-80">Attach evidence, map to frameworks, track remediation.</p>
        </div>
        <div className="card">
          <h2 className="font-semibold mb-2">Board-Ready KPIs</h2>
          <p className="opacity-80">Snapshot of risk posture your board actually understands.</p>
        </div>
      </div>
    </section>
  );
}
'@
Write-File (Join-Path $appDir 'page.tsx') $home
#endregion

#region Trust Network page
$trust = @'
export const metadata = { alternates: { canonical: "/trust-network" } };

export default async function Page() {
  // static marketing view of the network
  const bullets = [
    "Shared vendor profiles with reusable Q&A",
    "Live health endpoints & uptime signals",
    "Evidence attachments and control mappings"
  ];
  return (
    <section className="mt-10">
      <h1 className="text-2xl font-semibold mb-3">Vendor Trust Network</h1>
      <div className="card">
        <ul className="list-disc pl-6">
          {bullets.map((b) => <li key={b} className="opacity-80">{b}</li>)}
        </ul>
      </div>
    </section>
  );
}
'@
Write-File (Join-Path $trustDir 'page.tsx') $trust
#endregion

#region Vendors page (fetch /api/vendors with graceful fallback)
$vendorsPage = @'
type Vendor = { id?: string; name?: string; tier?: string; score?: number };

async function fetchVendors(): Promise<Vendor[]> {
  try {
    const res = await fetch("https://truvern.com/api/vendors", { next: { revalidate: 60 } });
    if (!res.ok) return [];
    const data = await res.json();
    if (Array.isArray(data)) return data as Vendor[];
    if (Array.isArray((data as any).vendors)) return (data as any).vendors as Vendor[];
    return [];
  } catch {
    return [];
  }
}

export const metadata = { alternates: { canonical: "/vendors" } };

export default async function Page() {
  const vendors = await fetchVendors();
  const view = vendors.length ? vendors : [
    { name: "Acme Cloud", tier: "Gold", score: 92 },
    { name: "Cobalt Data", tier: "Silver", score: 84 },
    { name: "Nimbus AI", tier: "Bronze", score: 78 }
  ];

  return (
    <section className="mt-10">
      <h1 className="text-2xl font-semibold mb-3">Vendors</h1>
      <div className="grid-3">
        {view.map((v, i) => (
          <div key={(v.id||i).toString()} className="card">
            <div className="flex items-center justify-between">
              <div>
                <div className="font-semibold">{v.name}</div>
                <div className="opacity-70 text-sm">Tier: {v.tier || "—"}</div>
              </div>
              <div className="text-right">
                <div className="text-2xl font-bold">{v.score ?? "—"}</div>
                <div className="opacity-70 text-xs">score</div>
              </div>
            </div>
          </div>
        ))}
      </div>
    </section>
  );
}
'@
Write-File (Join-Path $vendorsDir 'page.tsx') $vendorsPage
#endregion

#region Board report page
$board = @'
export const metadata = { alternates: { canonical: "/reports/board" } };

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="card">
      <div className="opacity-70 text-sm">{label}</div>
      <div className="text-2xl font-semibold mt-1">{value}</div>
    </div>
  );
}

export default function Page() {
  const stats = [
    { label: "Vendors assessed", value: "132" },
    { label: "Open remediations", value: "11" },
    { label: "Avg. risk score", value: "86" }
  ];
  return (
    <section className="mt-10">
      <h1 className="text-2xl font-semibold mb-3">Board Summary</h1>
      <div className="grid-3">{stats.map((s) => <Stat key={s.label} {...s} />)}</div>
      <div className="card mt-6">
        <div className="opacity-80">Trend lines and exportable CSV live in product.</div>
      </div>
    </section>
  );
}
'@
Write-File (Join-Path $reportsDir 'page.tsx') $board
#endregion

#region Auth: login / signup (non-functional placeholders)
$login = @'
export const metadata = { alternates: { canonical: "/login" }, title: "Log in" };

export default function Page() {
  return (
    <section className="mt-10 max-w-md mx-auto card">
      <h1 className="text-xl font-semibold mb-4">Log in</h1>
      <form className="flex flex-col gap-3">
        <input className="card" placeholder="Email" />
        <input className="card" placeholder="Password" type="password" />
        <button className="btn btn-primary" type="submit">Continue</button>
      </form>
      <div className="opacity-70 text-sm mt-3">
        No account? <a className="underline" href="/signup">Sign up</a>
      </div>
    </section>
  );
}
'@
Write-File (Join-Path $authLoginDir 'page.tsx') $login

$signup = @'
export const metadata = { alternates: { canonical: "/signup" }, title: "Sign up" };

export default function Page() {
  return (
    <section className="mt-10 max-w-md mx-auto card">
      <h1 className="text-xl font-semibold mb-4">Create account</h1>
      <form className="flex flex-col gap-3">
        <input className="card" placeholder="Name" />
        <input className="card" placeholder="Work email" />
        <input className="card" placeholder="Password" type="password" />
        <button className="btn btn-primary" type="submit">Create account</button>
      </form>
      <div className="opacity-70 text-sm mt-3">
        Already have an account? <a className="underline" href="/login">Log in</a>
      </div>
    </section>
  );
}
'@
Write-File (Join-Path $authSignupDir 'page.tsx') $signup
#endregion

#region Dashboard placeholder
$dashboard = @'
export const metadata = { alternates: { canonical: "/dashboard" }, title: "Dashboard" };

export default function Page() {
  return (
    <section className="mt-10">
      <h1 className="text-2xl font-semibold mb-3">Your Dashboard</h1>
      <div className="card">This is a placeholder. After auth is wired, user KPIs will render here.</div>
    </section>
  );
}
'@
Write-File (Join-Path $dashboardDir 'page.tsx') $dashboard
#endregion

#region Ensure favicon/og image exist (Phase141 should have done this)
$ogImg = Join-Path $publicDir 'opengraph-image.png'
if (-not (Test-Path $ogImg)) { Set-Content -Path $ogImg -Value 'Truvern OpenGraph Image' -Encoding UTF8; Log 'OG image placeholder created' }
$favicon = Join-Path $publicDir 'favicon.ico'
if (-not (Test-Path $favicon)) {
  $tinyIcoB64 = 'AAABAAEAEBAAAAAAIABoAwAAFgAAACgAAAAQAAAAIAAAAAEABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
  [IO.File]::WriteAllBytes($favicon,[Convert]::FromBase64String($tinyIcoB64)); Log 'Favicon placeholder created'
}
#endregion

#region Optional: Vercel build + deploy
$vercel = Get-Command vercel -ErrorAction SilentlyContinue
if ($vercel) {
  try {
    Log 'Vercel CLI detected. Building…'
    cmd /c 'vercel build' | Tee-Object -FilePath $logFile -Append | Out-Null
    Log 'Deploying prebuilt to prod…'
    cmd /c 'vercel deploy --prebuilt --prod' | Tee-Object -FilePath $logFile -Append | Out-Null
  } catch {
    Log ('Vercel step failed: ' + $_.Exception.Message) 'WARN'
  }
} else {
  Log 'Vercel CLI not found; skipping deploy.' 'WARN'
}
#endregion

Write-Host "`nPhase144 content bootstrap complete." -ForegroundColor Green
Write-Host ("Backups: " + $backups)
Write-Host ("Log:     " + $logFile)
