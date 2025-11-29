<# =====================================================================
 Phase157-DashboardEvidence-Fix.ps1
 Goal:
   - Ensure /dashboard/evidence has a valid App Router page
   - Create a simple dashboard layout for /dashboard/*
   - Rebuild and run vercel build + deploy --prebuilt --prod
 ===================================================================== #>

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Safety: do not run from system32
if ((Get-Location).Path -match '\\Windows\\System32$') {
    Write-Host "Please cd into your truvern folder (e.g. C:\Users\MR.NELSON\Downloads\truvern)" -ForegroundColor Red
    exit 1
}

$root = $PWD.Path
$ts   = Get-Date -Format "yyyyMMdd-HHmmss"
$backupDir = Join-Path $root ("patch_backups\phase157-" + $ts)
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null

function BackupItem {
    param([string]$PathToBackup)
    if (Test-Path $PathToBackup) {
        $leaf = Split-Path $PathToBackup -Leaf
        $dest = Join-Path $backupDir $leaf
        Copy-Item $PathToBackup $dest -Recurse -Force
        Write-Host ("Backup -> " + $dest)
    }
}

Write-Host "=== Phase157: Dashboard Evidence Fix ===" -ForegroundColor Cyan
Write-Host ""

# --------------------------------------------------------------------
# 1) Ensure app\dashboard layout exists (dashboard look & feel)
# --------------------------------------------------------------------

$dashboardDir     = Join-Path $root "app\dashboard"
$dashboardLayout  = Join-Path $dashboardDir "layout.tsx"

if (-not (Test-Path $dashboardDir)) {
    New-Item -ItemType Directory -Path $dashboardDir -Force | Out-Null
    Write-Host "Created app\dashboard folder."
}

if (Test-Path $dashboardLayout) {
    Write-Host "Existing app\dashboard\layout.tsx found. Backing up..." -ForegroundColor Yellow
    BackupItem $dashboardLayout
}

@'
import type { Metadata } from "next";
import React from "react";

export const metadata: Metadata = {
  title: {
    default: "Truvern dashboard",
    template: "%s | Truvern dashboard",
  },
  description:
    "Truvern dashboard for TPRM assessments, evidence and vendor trust network views.",
};

export default function DashboardLayout(props: {
  children: React.ReactNode;
}) {
  return (
    <div className="min-h-screen bg-slate-950 text-slate-50">
      <header className="border-b border-slate-800 bg-slate-900/70 backdrop-blur">
        <div className="mx-auto flex max-w-6xl items-center justify-between px-6 py-3">
          <div className="text-sm font-semibold tracking-tight">
            Truvern dashboard
          </div>
          <nav className="flex gap-4 text-xs opacity-80">
            <span>/trust-network</span>
            <span>/reports/board</span>
            <span>/vendors</span>
          </nav>
        </div>
      </header>

      <main className="mx-auto flex max-w-6xl gap-6 px-6 py-6">
        <aside className="hidden w-56 flex-shrink-0 rounded-lg border border-slate-800 bg-slate-900/60 p-4 text-xs md:block">
          <div className="mb-3 text-[11px] font-semibold uppercase tracking-wide text-slate-400">
            Sections
          </div>
          <ul className="space-y-1 text-slate-300">
            <li>Overview</li>
            <li className="font-semibold text-sky-300">Evidence</li>
            <li>Vendors</li>
            <li>Assessments</li>
            <li>Usage & billing</li>
          </ul>
        </aside>

        <section className="flex-1 rounded-lg border border-slate-800 bg-slate-900/60 p-5">
          {props.children}
        </section>
      </main>
    </div>
  );
}
'@ | Set-Content -Path $dashboardLayout -Encoding UTF8

Write-Host "Dashboard layout ensured at app\dashboard\layout.tsx." -ForegroundColor Green

# --------------------------------------------------------------------
# 2) Create / fix app\dashboard\evidence\page.tsx
# --------------------------------------------------------------------

$evidenceDir  = Join-Path $dashboardDir "evidence"
$evidencePage = Join-Path $evidenceDir "page.tsx"

if (-not (Test-Path $evidenceDir)) {
    New-Item -ItemType Directory -Path $evidenceDir -Force | Out-Null
    Write-Host "Created app\dashboard\evidence folder."
}

if (Test-Path $evidencePage) {
    Write-Host "Existing app\dashboard\evidence\page.tsx found. Backing up..." -ForegroundColor Yellow
    BackupItem $evidencePage
}

@'
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Evidence workspace",
  description:
    "Central workspace for Truvern evidence uploads, mappings, and board-ready documentation.",
  alternates: {
    canonical: "/dashboard/evidence",
  },
  openGraph: {
    title: "Truvern evidence workspace",
    description:
      "Manage vendor evidence, attach documents to controls, and prepare board-ready reports.",
    url: "https://truvern.com/dashboard/evidence",
    images: ["/opengraph-image.png"],
  },
};

export default function EvidenceDashboardPage() {
  return (
    <div className="space-y-6">
      <header className="border-b border-slate-800 pb-4">
        <h1 className="text-xl font-semibold tracking-tight">
          Evidence workspace
        </h1>
        <p className="mt-1 text-sm text-slate-300">
          Review uploaded artifacts, map them to controls, and confirm what is
          ready for board reporting.
        </p>
      </header>

      <section className="grid gap-4 md:grid-cols-3">
        <div className="rounded-lg border border-slate-800 bg-slate-950/60 p-4 text-sm">
          <h2 className="mb-2 text-[13px] font-semibold tracking-wide text-slate-300">
            Incoming evidence
          </h2>
          <p className="text-xs text-slate-400">
            Placeholder list for new vendor uploads, SOC reports, policies and
            other files awaiting review.
          </p>
        </div>

        <div className="rounded-lg border border-slate-800 bg-slate-950/60 p-4 text-sm">
          <h2 className="mb-2 text-[13px] font-semibold tracking-wide text-slate-300">
            Control mappings
          </h2>
          <p className="text-xs text-slate-400">
            Future view for mapping evidence to specific Truvern control
            domains and risk themes.
          </p>
        </div>

        <div className="rounded-lg border border-slate-800 bg-slate-950/60 p-4 text-sm">
          <h2 className="mb-2 text-[13px] font-semibold tracking-wide text-slate-300">
            Board-ready bundle
          </h2>
          <p className="text-xs text-slate-400">
            This panel will surface the subset of evidence referenced by the
            /reports/board view once wiring is complete.
          </p>
        </div>
      </section>
    </div>
  );
}
'@ | Set-Content -Path $evidencePage -Encoding UTF8

Write-Host "Evidence page ensured at app\dashboard\evidence\page.tsx." -ForegroundColor Green

# --------------------------------------------------------------------
# 3) Clean build artifacts
# --------------------------------------------------------------------

Write-Host "`nCleaning .next and .vercel/output..." -ForegroundColor Yellow
if (Test-Path ".next")          { Remove-Item ".next" -Recurse -Force }
if (Test-Path ".vercel\output") { Remove-Item ".vercel\output" -Recurse -Force }

# --------------------------------------------------------------------
# 4) Local Next.js build
# --------------------------------------------------------------------

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
    Write-Host "No pnpm, npm, or yarn found; skipping local build." -ForegroundColor Red
}

# --------------------------------------------------------------------
# 5) Vercel prebuilt deploy (if CLI is available)
# --------------------------------------------------------------------

if (Get-Command vercel -ErrorAction SilentlyContinue) {
    Write-Host "`nRunning vercel build + vercel deploy --prebuilt --prod..." -ForegroundColor Yellow
    vercel build
    vercel deploy --prebuilt --prod
} else {
    Write-Host "Vercel CLI not found; skipping deploy step." -ForegroundColor Yellow
}

Write-Host "`nPhase157 complete." -ForegroundColor Green
