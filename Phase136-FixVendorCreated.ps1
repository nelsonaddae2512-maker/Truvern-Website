$ErrorActionPreference = "Stop"

Write-Host "=== Phase136: Fix Vendor Created Column ===" -ForegroundColor Cyan

# Always work from the project directory
$root = $PSScriptRoot
Set-Location $root
Write-Host "[INFO] Working in: $root" -ForegroundColor DarkCyan

# Paths
$vendorsDir  = Join-Path $root "app\vendors"
$pagePath    = Join-Path $vendorsDir "page.tsx"

# 1) Ensure app/vendors directory exists
if (-not (Test-Path $vendorsDir)) {
    New-Item -ItemType Directory -Path $vendorsDir | Out-Null
    Write-Host "[INFO] Created app/vendors directory." -ForegroundColor Yellow
} else {
    Write-Host "[INFO] app/vendors directory already exists." -ForegroundColor DarkYellow
}

# 2) Backup existing page.tsx if it exists
if (Test-Path $pagePath) {
    $stamp      = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupPath = "$pagePath.bak-$stamp"
    Copy-Item $pagePath $backupPath
    Write-Host "[INFO] Backed up existing vendors/page.tsx to: $backupPath" -ForegroundColor DarkYellow
}

# 3) Write new vendors/page.tsx that safely handles Created date
$pageContent = @'
import Link from "next/link";
import { prisma } from "@/lib/prisma";

export const dynamic = "force-dynamic";

function formatCreated(v: any): string {
  // Prefer vendor.createdAt if it ever exists
  const direct = (v as any).createdAt as Date | string | undefined;
  const fromAssessment =
    v.assessments && v.assessments[0]?.createdAt
      ? (v.assessments[0].createdAt as Date | string)
      : undefined;

  const source = direct ?? fromAssessment;
  if (!source) return "—";

  const d = new Date(source);
  if (Number.isNaN(d.getTime())) return "—";

  return d.toLocaleDateString();
}

export default async function VendorsPage() {
  const vendors = await prisma.vendor.findMany({
    orderBy: { name: "asc" },
    include: {
      assessments: {
        orderBy: { createdAt: "desc" },
        take: 1, // we only need the most recent assessment for Created
      },
    },
  });

  return (
    <main className="min-h-screen bg-slate-950 text-slate-50">
      <section className="max-w-6xl mx-auto px-4 py-10 space-y-6">
        <header className="space-y-2">
          <p className="text-xs uppercase tracking-[0.2em] text-sky-400">
            Truvern · Vendor catalogue
          </p>
          <h1 className="text-2xl md:text-3xl font-semibold">
            Vendors in third-party risk scope
          </h1>
          <p className="text-sm text-slate-300 max-w-2xl">
            This view pulls directly from your Vendor table. Click a row to
            navigate to the vendor profile and view recent assessments.
          </p>
        </header>

        <div className="overflow-x-auto rounded-lg border border-slate-800 bg-slate-900/40">
          <table className="min-w-full text-sm">
            <thead className="bg-slate-900/80 border-b border-slate-800">
              <tr>
                <th className="px-4 py-2 text-left font-medium text-slate-300">
                  Name
                </th>
                <th className="px-4 py-2 text-left font-medium text-slate-300">
                  Risk score
                </th>
                <th className="px-4 py-2 text-left font-medium text-slate-300">
                  Created
                </th>
                <th className="px-4 py-2 text-right font-medium text-slate-300">
                  Assessments
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
                    Truvern, they will appear here.
                  </td>
                </tr>
              )}

              {vendors.map((v) => (
                <tr
                  key={v.id}
                  className="border-t border-slate-800 hover:bg-slate-900/60 transition"
                >
                  <td className="px-4 py-2">
                    <Link
                      href={`/vendors/${v.id}`}
                      className="text-sky-300 hover:underline"
                    >
                      {v.name}
                    </Link>
                  </td>
                  <td className="px-4 py-2 text-slate-100">
                    {v.riskScore ?? "—"}
                  </td>
                  <td className="px-4 py-2 text-slate-400">
                    {formatCreated(v)}
                  </td>
                  <td className="px-4 py-2 text-right text-slate-400">
                    {v.assessments ? v.assessments.length : 0}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </main>
  );
}
'@

Set-Content -Path $pagePath -Value $pageContent -Encoding UTF8
Write-Host "[INFO] Wrote updated app/vendors/page.tsx with safe Created column." -ForegroundColor Green

# 4) Trigger cloud deploy so the change is live
$deployScript = Join-Path $root "Phase132g-CloudDeploy.ps1"
if (Test-Path $deployScript) {
    Write-Host "[STEP] Running Phase132g-CloudDeploy.ps1..." -ForegroundColor Cyan
    & $deployScript
} else {
    Write-Host "[STEP] Running 'vercel --prod --yes' (fallback)..." -ForegroundColor Cyan
    vercel --prod --yes
}

Write-Host "=== Phase136-FixVendorCreated complete ===" -ForegroundColor Cyan
