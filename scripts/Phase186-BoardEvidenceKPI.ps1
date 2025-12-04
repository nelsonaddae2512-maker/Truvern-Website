# ==============================================
# Phase186 - Board Evidence KPIs & Vendor Table
# ==============================================

param()

$projectRoot = "C:\Users\MR.NELSON\Downloads\truvern"
$logDir      = "$projectRoot\scripts\logs"
$timestamp   = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile     = "$logDir\phase186-board-evidence-kpi-$timestamp.log"

if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

function Write-Log {
    param(
        [string]$Message,
        [string]$Color = "Cyan"
    )
    Write-Host $Message -ForegroundColor $Color
    Add-Content -Path $logFile -Value ("[{0}] {1}" -f (Get-Date), $Message)
}

Write-Log "===== Phase186: Board Evidence KPI START =====" "Yellow"

# ------------------------------------------------------------------
# Ensure correct working directory (never run from system32)
# ------------------------------------------------------------------
if ((Get-Location).Path -ne $projectRoot) {
    Write-Log "Switching to project root: $projectRoot" "Green"
    Set-Location $projectRoot
}

Write-Log "Current Directory: $(Get-Location)" "Green"

# ------------------------------------------------------------------
# Ensure board report directory exists
# ------------------------------------------------------------------
$boardDir  = Join-Path $projectRoot "app\reports\board"
$boardFile = Join-Path $boardDir "page.tsx"

if (-not (Test-Path $boardDir)) {
    Write-Log "Creating board report directory: $boardDir" "Yellow"
    New-Item -Path $boardDir -ItemType Directory -Force | Out-Null
}

# ------------------------------------------------------------------
# Write board report page with evidence KPIs
# ------------------------------------------------------------------
Write-Log "Writing board report page: $boardFile" "Yellow"

@'
import prisma from "@/lib/prisma";
import Link from "next/link";

export const dynamic = "force-dynamic";

type VendorRow = {
  id: number;
  name: string;
  riskScore: number | null;
  evidenceCount: number;
};

export default async function BoardReportPage() {
  const vendors = await prisma.vendor.findMany({
    orderBy: { name: "asc" },
    include: {
      evidence: true,
    },
  });

  const rows: VendorRow[] = vendors.map((v) => ({
    id: v.id,
    name: v.name,
    riskScore: v.riskScore ?? null,
    evidenceCount: v.evidence.length,
  }));

  const totalVendors = rows.length;
  const vendorsWithEvidence = rows.filter((r) => r.evidenceCount > 0).length;
  const totalEvidence = rows.reduce((sum, r) => sum + r.evidenceCount, 0);

  return (
    <div className="min-h-screen bg-slate-950 text-slate-50">
      <main className="max-w-5xl mx-auto px-4 py-10">
        <header className="mb-10">
          <h1 className="text-3xl font-semibold tracking-tight mb-2">
            Board Risk Report
          </h1>
          <p className="text-slate-400">
            Overview of third-party risk posture and supporting evidence.
          </p>
        </header>

        {/* KPI stripe */}
        <section className="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-10">
          <div className="rounded-xl border border-emerald-500/40 bg-emerald-500/5 px-4 py-3">
            <p className="text-xs font-semibold uppercase tracking-wide text-emerald-300">
              Total vendors
            </p>
            <p className="mt-2 text-2xl font-semibold">{totalVendors}</p>
          </div>
          <div className="rounded-xl border border-sky-500/40 bg-sky-500/5 px-4 py-3">
            <p className="text-xs font-semibold uppercase tracking-wide text-sky-300">
              Vendors with evidence
            </p>
            <p className="mt-2 text-2xl font-semibold">{vendorsWithEvidence}</p>
          </div>
          <div className="rounded-xl border border-amber-500/40 bg-amber-500/5 px-4 py-3">
            <p className="text-xs font-semibold uppercase tracking-wide text-amber-300">
              Evidence items
            </p>
            <p className="mt-2 text-2xl font-semibold">{totalEvidence}</p>
          </div>
        </section>

        {/* Vendor table */}
        <section className="bg-slate-900/70 rounded-xl border border-slate-800 shadow-lg overflow-hidden">
          <div className="px-6 py-4 border-b border-slate-800 flex items-center justify-between">
            <h2 className="text-sm font-semibold tracking-wide text-slate-300 uppercase">
              Vendors
            </h2>
            <span className="text-xs text-slate-500">
              Click a vendor to view detailed evidence
            </span>
          </div>
          <div className="overflow-x-auto">
            <table className="min-w-full text-sm">
              <thead className="bg-slate-900">
                <tr>
                  <th className="px-6 py-3 text-left font-medium text-slate-400 uppercase tracking-wide">
                    Vendor
                  </th>
                  <th className="px-6 py-3 text-left font-medium text-slate-400 uppercase tracking-wide">
                    Risk score
                  </th>
                  <th className="px-6 py-3 text-left font-medium text-slate-400 uppercase tracking-wide">
                    Evidence
                  </th>
                </tr>
              </thead>
              <tbody>
                {rows.map((v, idx) => (
                  <tr
                    key={v.id}
                    className={
                      idx % 2 === 0 ? "bg-slate-900/40" : "bg-slate-900/20"
                    }
                  >
                    <td className="px-6 py-3">
                      <Link
                        href={`/vendors/${v.id}`}
                        className="text-emerald-400 hover:text-emerald-300 hover:underline"
                      >
                        {v.name}
                      </Link>
                    </td>
                    <td className="px-6 py-3">
                      {v.riskScore !== null ? v.riskScore : "—"}
                    </td>
                    <td className="px-6 py-3">
                      <span className="inline-flex items-center rounded-full border border-slate-700 px-2.5 py-1 text-xs font-medium">
                        {v.evidenceCount}
                        <span className="ml-1 text-slate-400">
                          {v.evidenceCount === 1 ? "item" : "items"}
                        </span>
                      </span>
                    </td>
                  </tr>
                ))}
                {rows.length === 0 && (
                  <tr>
                    <td
                      colSpan={3}
                      className="px-6 py-6 text-center text-slate-500"
                    >
                      No vendors found yet.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </section>
      </main>
    </div>
  );
}
'@ | Set-Content -Path $boardFile -Encoding UTF8

Write-Log "Board report page written." "Green"

# ------------------------------------------------------------------
# Git add / commit / push
# ------------------------------------------------------------------
Write-Log "Staging board report + Phase186 script..." "Yellow"
git add "app/reports/board/page.tsx" "scripts/Phase186-BoardEvidenceKPI.ps1"

Write-Log "Creating commit..." "Yellow"
git commit -m "Phase186: add evidence KPIs to board report" | Tee-Object -FilePath $logFile -Append

Write-Log "Pushing to origin/main..." "Yellow"
git push | Tee-Object -FilePath $logFile -Append

# ------------------------------------------------------------------
# Re-run Phase180 health check
# ------------------------------------------------------------------
$healthScript = Join-Path $projectRoot "scripts\Phase180-RouteHealthCheck.ps1"
if (Test-Path $healthScript) {
    Write-Log "Running Phase180 route health check..." "Yellow"
    & $healthScript
} else {
    Write-Log "Phase180 health script not found at $healthScript - skipping health check." "Red"
}

Write-Log "===== Phase186: Board Evidence KPI COMPLETE =====" "Yellow"
