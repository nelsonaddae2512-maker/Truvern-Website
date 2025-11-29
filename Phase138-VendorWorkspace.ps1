$ErrorActionPreference = "Stop"

Write-Host "=== Phase138: Vendor Workspace Overview ===" -ForegroundColor Cyan

# Always work from the project directory
$root = $PSScriptRoot
Set-Location $root
Write-Host "[INFO] Working in: $root" -ForegroundColor DarkCyan

# Paths
$vendorDir = Join-Path $root "app\vendor"
$pagePath  = Join-Path $vendorDir "page.tsx"

# 1) Ensure app/vendor directory exists
if (-not (Test-Path $vendorDir)) {
    New-Item -ItemType Directory -Path $vendorDir | Out-Null
    Write-Host "[INFO] Created app/vendor directory." -ForegroundColor Yellow
} else {
    Write-Host "[INFO] app/vendor directory already exists." -ForegroundColor DarkYellow
}

# 2) Backup existing page.tsx if it exists (this was the old Phase118 placeholder)
if (Test-Path $pagePath) {
    $stamp      = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupPath = "$pagePath.bak-$stamp"
    Copy-Item $pagePath $backupPath
    Write-Host "[INFO] Backed up existing vendor/page.tsx to: $backupPath" -ForegroundColor DarkYellow
}

# 3) Write new vendor/page.tsx (Vendor Workspace overview)
$pageContent = @'
import Link from "next/link";
import { prisma } from "@/lib/prisma";

export const dynamic = "force-dynamic";

type WorkspaceVendor = {
  id: number;
  name: string;
  riskScore: number | null;
  assessments: { createdAt: Date }[];
};

function formatLatestAssessment(v: WorkspaceVendor): string {
  const latest = v.assessments?.[0];
  if (!latest) return "No assessments yet";

  const d = new Date(latest.createdAt);
  if (Number.isNaN(d.getTime())) return "No assessments yet";

  return d.toLocaleDateString();
}

export default async function VendorWorkspacePage() {
  // For now, we show a small sample of vendors from the main vendor table.
  // In a future phase, this will be scoped to the logged-in vendor (magic link, SSO, etc.).
  const vendors = (await prisma.vendor.findMany({
    orderBy: { riskScore: "desc" },
    take: 10,
    include: {
      assessments: {
        orderBy: { createdAt: "desc" },
        take: 1,
      },
    },
  })) as WorkspaceVendor[];

  return (
    <main className="min-h-screen bg-slate-950 text-slate-50">
      <section className="max-w-5xl mx-auto px-4 py-10 space-y-8">
        <header className="space-y-3">
          <p className="text-xs uppercase tracking-[0.25em] text-sky-400">
            Truvern · Vendor workspace
          </p>
          <h1 className="text-3xl md:text-4xl font-semibold">
            One workspace for vendor assessments and evidence.
          </h1>
          <p className="text-sm md:text-base text-slate-300 max-w-3xl">
            This workspace is where vendors come to answer questionnaires, upload
            evidence, and see exactly how they are being scored. When shared via
            a secure link or SSO, the view is scoped to a single vendor.
          </p>
        </header>

        <section className="grid gap-4 md:grid-cols-3">
          <div className="rounded-lg border border-slate-800 bg-slate-900/40 p-4 space-y-2">
            <p className="text-xs font-medium text-slate-400 uppercase tracking-wide">
              Step 1 · Profile
            </p>
            <p className="text-sm text-slate-100">
              Vendors keep a single source-of-truth profile instead of filling
              out the same basics for every customer.
            </p>
          </div>
          <div className="rounded-lg border border-slate-800 bg-slate-900/40 p-4 space-y-2">
            <p className="text-xs font-medium text-slate-400 uppercase tracking-wide">
              Step 2 · Questionnaire
            </p>
            <p className="text-sm text-slate-100">
              Complete standardized questionnaires once and re-use the answers
              across multiple customers on the trust network.
            </p>
          </div>
          <div className="rounded-lg border border-slate-800 bg-slate-900/40 p-4 space-y-2">
            <p className="text-xs font-medium text-slate-400 uppercase tracking-wide">
              Step 3 · Evidence
            </p>
            <p className="text-sm text-slate-100">
              Upload SOC reports, pen tests, and policies, then track expiry and
              remediation directly from the workspace.
            </p>
          </div>
        </section>

        <section className="space-y-3">
          <div className="flex items-center justify-between gap-2">
            <h2 className="text-lg font-semibold">
              Sample vendor workspace entries
            </h2>
            <Link
              href="/vendors"
              className="text-xs text-sky-300 hover:underline"
            >
              View full vendor list
            </Link>
          </div>

          <div className="overflow-x-auto rounded-lg border border-slate-800 bg-slate-900/40">
            <table className="min-w-full text-sm">
              <thead className="bg-slate-900/80 border-b border-slate-800">
                <tr>
                  <th className="px-4 py-2 text-left font-medium text-slate-300">
                    Vendor
                  </th>
                  <th className="px-4 py-2 text-left font-medium text-slate-300">
                    Risk score
                  </th>
                  <th className="px-4 py-2 text-left font-medium text-slate-300">
                    Latest assessment
                  </th>
                  <th className="px-4 py-2 text-right font-medium text-slate-300">
                    Workspace
                  </th>
                </tr>
              </thead>
              <tbody>
                {vendors.length === 0 && (
                  <tr>
                    <td
                      colSpan={4}
                      className="px-4 py-6 text-center text-sm text-slate-400"
                    >
                      No vendors found yet. Once vendors are onboarded into
                      Truvern, their workspace links will appear here.
                    </td>
                  </tr>
                )}
                {vendors.map((v) => (
                  <tr
                    key={v.id}
                    className="border-t border-slate-800 hover:bg-slate-900/60 transition"
                  >
                    <td className="px-4 py-2">
                      <span className="text-slate-50">{v.name}</span>
                    </td>
                    <td className="px-4 py-2 text-slate-100">
                      {v.riskScore ?? "—"}
                    </td>
                    <td className="px-4 py-2 text-slate-400">
                      {formatLatestAssessment(v)}
                    </td>
                    <td className="px-4 py-2 text-right">
                      <Link
                        href={`/vendors/${v.id}`}
                        className="inline-flex items-center rounded-md border border-sky-500/60 px-3 py-1 text-xs font-medium text-sky-300 hover:bg-sky-500/10 transition"
                      >
                        Open workspace
                      </Link>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>

        <section className="pt-2 border-t border-slate-800 text-xs text-slate-500 space-y-1">
          <p>
            For real vendors, this page is only accessible via a secure link
            or SSO connection. This environment currently shows a sample view
            based on your internal vendor catalogue.
          </p>
        </section>
      </section>
    </main>
  );
}
'@

Set-Content -Path $pagePath -Value $pageContent -Encoding UTF8
Write-Host "[INFO] Wrote updated app/vendor/page.tsx (Vendor Workspace overview)." -ForegroundColor Green

# 4) Trigger cloud deploy so the workspace is live
$deployScript = Join-Path $root "Phase132g-CloudDeploy.ps1"
if (Test-Path $deployScript) {
    Write-Host "[STEP] Running Phase132g-CloudDeploy.ps1..." -ForegroundColor Cyan
    & $deployScript
} else {
    Write-Host "[STEP] Running 'vercel --prod --yes' (fallback)..." -ForegroundColor Cyan
    vercel --prod --yes
}

Write-Host "=== Phase138-VendorWorkspace complete ===" -ForegroundColor Cyan
