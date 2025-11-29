<# 
    Phase133-ContentScaffold.ps1
    -----------------------------------------
    - Overwrites three placeholder pages that were added by Phase118:
        app/page.tsx                -> Marketing-style homepage
        app/trust-network/page.tsx  -> Trust Network explainer
        app/vendors/page.tsx        -> Vendor workspace explainer
    - All pages are static, styled with Tailwind utility classes,
      and contain no "safe placeholder" text.
#>

param(
    [string]$ProjectDir = $PSScriptRoot
)

$ErrorActionPreference = "Stop"

Write-Host "=== Phase133: Content Scaffold for Core Pages ===" -ForegroundColor Magenta

try {
    if (-not $ProjectDir -or $ProjectDir -eq "") {
        $ProjectDir = $PSScriptRoot
    }
    $projectPath = Resolve-Path $ProjectDir
} catch {
    Write-Host "[ERROR] Unable to resolve ProjectDir." -ForegroundColor Red
    exit 1
}

if ($PWD.Path -like "*System32*") {
    Set-Location $projectPath
} else {
    Set-Location $projectPath
}

Write-Host "[INFO] Working in: $((Get-Location).Path)" -ForegroundColor Cyan

# Ensure app directories exist
$homeDir   = Join-Path $projectPath "app"
$trustDir  = Join-Path $projectPath "app\trust-network"
$vendorsDir= Join-Path $projectPath "app\vendors"

foreach ($d in @($homeDir, $trustDir, $vendorsDir)) {
    if (-not (Test-Path $d)) {
        New-Item -Path $d -ItemType Directory -Force | Out-Null
    }
}

# 1) app/page.tsx  (homepage)
$homePagePath = Join-Path $homeDir "page.tsx"
$homePageContent = @"
import Link from "next/link";

export const dynamic = "force-static";

export default function HomePage() {
  return (
    <main className="min-h-screen bg-slate-950 text-slate-50">
      <section className="max-w-5xl mx-auto px-4 py-16 space-y-10">
        <div className="space-y-4">
          <p className="text-xs uppercase tracking-[0.2em] text-sky-400">
            Truvern · Third-Party Risk Network
          </p>
          <h1 className="text-3xl md:text-4xl font-semibold leading-tight">
            One place to see, prove, and share{" "}
            <span className="text-sky-400">third-party risk posture</span>.
          </h1>
          <p className="text-sm md:text-base text-slate-300 max-w-2xl">
            Truvern connects your vendors, evidence, and board-level reporting
            in a single, always-current trust network. No spreadsheet rodeos,
            no one-off questionnaires, just clear answers you can defend.
          </p>
        </div>

        <div className="flex flex-wrap gap-3">
          <Link
            href="/trust-network"
            className="inline-flex items-center rounded-md bg-sky-500 px-4 py-2 text-sm font-medium text-slate-950 hover:bg-sky-400 transition"
          >
            View Trust Network
          </Link>
          <Link
            href="/vendors"
            className="inline-flex items-center rounded-md border border-slate-700 px-4 py-2 text-sm font-medium text-slate-100 hover:bg-slate-900 transition"
          >
            Open Vendor Workspace
          </Link>
        </div>

        <div className="grid gap-4 md:grid-cols-3 text-xs md:text-sm text-slate-300">
          <div className="rounded-lg border border-slate-800 bg-slate-900/40 p-4 space-y-1">
            <p className="font-medium text-slate-100">Live vendor risk scores</p>
            <p>
              Normalize SIG, CAIQ, custom questionnaires, and evidence into a
              single health score per vendor.
            </p>
          </div>
          <div className="rounded-lg border border-slate-800 bg-slate-900/40 p-4 space-y-1">
            <p className="font-medium text-slate-100">Board-ready reports</p>
            <p>
              Export concise, defensible views for the board without exposing
              all the operational detail behind the scenes.
            </p>
          </div>
          <div className="rounded-lg border border-slate-800 bg-slate-900/40 p-4 space-y-1">
            <p className="font-medium text-slate-100">Vendor-friendly portal</p>
            <p>
              Give vendors one link where they can answer once, share everywhere,
              and track their own remediation.
            </p>
          </div>
        </div>
      </section>
    </main>
  );
}
"@

Set-Content -Path $homePagePath -Value $homePageContent -Encoding UTF8
Write-Host "[INFO] Wrote homepage: $homePagePath" -ForegroundColor Green

# 2) app/trust-network/page.tsx
$trustPagePath = Join-Path $trustDir "page.tsx"
$trustPageContent = @"
import Link from "next/link";

export const dynamic = "force-static";

export default function TrustNetworkPage() {
  return (
    <main className="min-h-screen bg-slate-950 text-slate-50">
      <section className="max-w-5xl mx-auto px-4 py-16 space-y-8">
        <header className="space-y-3">
          <p className="text-xs uppercase tracking-[0.2em] text-sky-400">
            Truvern Trust Network
          </p>
          <h1 className="text-2xl md:text-3xl font-semibold">
            A shared source of truth for third-party risk.
          </h1>
          <p className="text-sm md:text-base text-slate-300 max-w-2xl">
            The Trust Network lets customers and vendors meet in the middle:
            reusable assessments, shared evidence, and live health indicators
            for every relationship.
          </p>
        </header>

        <div className="grid gap-4 md:grid-cols-2 text-xs md:text-sm text-slate-300">
          <div className="rounded-lg border border-slate-800 bg-slate-900/40 p-4 space-y-2">
            <p className="font-medium text-slate-100">For customers</p>
            <ul className="space-y-1 list-disc list-inside">
              <li>Search the network for existing vendor profiles.</li>
              <li>Re-use completed assessments instead of starting from scratch.</li>
              <li>Track open risks and remediation plans in one view.</li>
            </ul>
          </div>
          <div className="rounded-lg border border-slate-800 bg-slate-900/40 p-4 space-y-2">
            <p className="font-medium text-slate-100">For vendors</p>
            <ul className="space-y-1 list-disc list-inside">
              <li>Maintain a single, always-current security profile.</li>
              <li>Answer once, share with many customers.</li>
              <li>Publish attestations, certifications, and evidence on your terms.</li>
            </ul>
          </div>
        </div>

        <div className="flex flex-wrap gap-3 text-xs md:text-sm">
          <Link
            href="/vendors"
            className="inline-flex items-center rounded-md bg-sky-500 px-4 py-2 text-sm font-medium text-slate-950 hover:bg-sky-400 transition"
          >
            Go to vendor workspace
          </Link>
          <span className="text-slate-400">
            Looking for the old placeholder? It has been replaced by this
            Trust Network overview.
          </span>
        </div>
      </section>
    </main>
  );
}
"@

Set-Content -Path $trustPagePath -Value $trustPageContent -Encoding UTF8
Write-Host "[INFO] Wrote trust network page: $trustPagePath" -ForegroundColor Green

# 3) app/vendors/page.tsx
$vendorsPagePath = Join-Path $vendorsDir "page.tsx"
$vendorsPageContent = @"
import Link from "next/link";

export const dynamic = "force-static";

export default function VendorsPage() {
  return (
    <main className="min-h-screen bg-slate-950 text-slate-50">
      <section className="max-w-5xl mx-auto px-4 py-16 space-y-8">
        <header className="space-y-3">
          <p className="text-xs uppercase tracking-[0.2em] text-sky-400">
            Vendor Workspace
          </p>
          <h1 className="text-2xl md:text-3xl font-semibold">
            A single workspace for all your customer assessments.
          </h1>
          <p className="text-sm md:text-base text-slate-300 max-w-2xl">
            This page replaces the temporary Phase118 placeholder. Use it as a
            starting point for your vendor portal: upload evidence, track
            questionnaires, and share your Truvern profile with customers.
          </p>
        </header>

        <div className="grid gap-4 md:grid-cols-2 text-xs md:text-sm text-slate-300">
          <div className="rounded-lg border border-slate-800 bg-slate-900/40 p-4 space-y-1">
            <p className="font-medium text-slate-100">What vendors see here</p>
            <ul className="space-y-1 list-disc list-inside">
              <li>Summary of open customer assessments.</li>
              <li>Links to upload artifacts and policies.</li>
              <li>Status of remediation items and due dates.</li>
            </ul>
          </div>
          <div className="rounded-lg border border-slate-800 bg-slate-900/40 p-4 space-y-1">
            <p className="font-medium text-slate-100">Next implementation step</p>
            <ul className="space-y-1 list-disc list-inside">
              <li>
                Wire this page to your existing <code>/api/vendors</code> and
                related endpoints.
              </li>
              <li>
                Add tables or cards that render real vendor records from the DB.
              </li>
            </ul>
          </div>
        </div>

        <p className="text-xs text-slate-500">
          Note: This is a static scaffold. It is safe for production while you
          continue wiring up the full vendor experience.
        </p>

        <div className="flex flex-wrap gap-3">
          <Link
            href="/"
            className="inline-flex items-center rounded-md border border-slate-700 px-4 py-2 text-sm font-medium text-slate-100 hover:bg-slate-900 transition"
          >
            Back to Truvern home
          </Link>
        </div>
      </section>
    </main>
  );
}
"@

Set-Content -Path $vendorsPagePath -Value $vendorsPageContent -Encoding UTF8
Write-Host "[INFO] Wrote vendors page: $vendorsPagePath" -ForegroundColor Green

Write-Host "✅ Phase133 complete: Core page scaffolds written." -ForegroundColor Green
exit 0
