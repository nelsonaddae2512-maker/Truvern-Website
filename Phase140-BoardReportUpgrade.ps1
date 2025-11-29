$ErrorActionPreference = "Stop"

Write-Host "=== Phase140: Board Report Upgrade (Reassessments + Templates) ===" -ForegroundColor Cyan

# Always work from the project directory
$root = $PSScriptRoot
Set-Location $root
Write-Host "[INFO] Working in: $root" -ForegroundColor DarkCyan

# Paths
$boardDir  = Join-Path $root "app\reports\board"
$pagePath  = Join-Path $boardDir "page.tsx"

# 1) Ensure app/reports/board directory exists
if (-not (Test-Path $boardDir)) {
    New-Item -ItemType Directory -Path $boardDir -Force | Out-Null
    Write-Host "[INFO] Created app/reports/board directory." -ForegroundColor Yellow
} else {
    Write-Host "[INFO] app/reports/board directory already exists." -ForegroundColor DarkYellow
}

# 2) Backup existing board/page.tsx if present
if (Test-Path $pagePath) {
    $stamp      = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupPath = "$pagePath.bak-$stamp"
    Copy-Item $pagePath $backupPath
    Write-Host "[INFO] Backed up existing reports/board/page.tsx to: $backupPath" -ForegroundColor DarkYellow
} else {
    Write-Host "[WARN] No existing reports/board/page.tsx found; writing new one." -ForegroundColor Yellow
}

# 3) Write upgraded Board Report page
$pageContent = @'
import { prisma } from "@/lib/prisma";
import Link from "next/link";

export const dynamic = "force-dynamic";

type BoardVendor = {
  id: number;
  name: string;
  riskScore: number | null;
  assessments: { createdAt: Date }[];
};

function tier(score: number | null): "low" | "medium" | "high" | "critical" {
  const s = score ?? 0;
  if (s >= 80) return "critical";
  if (s >= 60) return "high";
  if (s >= 40) return "medium";
  return "low";
}

function formatDate(input: Date | string | null | undefined): string {
  if (!input) return "—";
  const d = new Date(input);
  if (Number.isNaN(d.getTime())) return "—";
  return d.toLocaleDateString();
}

function addMonths(date: Date, months: number): Date {
  const d = new Date(date);
  d.setMonth(d.getMonth() + months);
  return d;
}

/**
 * Risk-based reassessment cadence:
 * - critical: 3 months
 * - high:     6 months
 * - medium:  12 months
 * - low:     24 months
 */
function calcReassessmentDate(v: BoardVendor): string {
  const latest = v.assessments?.[0];
  if (!latest) return "Not scheduled";

  const level = tier(v.riskScore);
  const base = new Date(latest.createdAt);

  const months =
    level === "critical"
      ? 3
      : level === "high"
      ? 6
      : level === "medium"
      ? 12
      : 24;

  const due = addMonths(base, months);
  return formatDate(due);
}

export default async function BoardReportPage() {
  const vendors = (await prisma.vendor.findMany({
    orderBy: { riskScore: "desc" },
    include: {
      assessments: {
        orderBy: { createdAt: "desc" },
        take: 1,
      },
    },
  })) as BoardVendor[];

  const totalVendors = vendors.length;
  const avgRiskScore =
    totalVendors === 0
      ? 0
      : Math.round(
          vendors.reduce((sum, v) => sum + (v.riskScore ?? 0), 0) /
            totalVendors
        );

  const withAssessments = vendors.filter((v) => v.assessments.length > 0);
  const coverage =
    totalVendors === 0
      ? 0
      : Math.round((withAssessments.length / totalVendors) * 100);

  const critical = vendors.filter((v) => tier(v.riskScore) === "critical");
  const high = vendors.filter((v) => tier(v.riskScore) === "high");
  const medium = vendors.filter((v) => tier(v.riskScore) === "medium");
  const low = vendors.filter((v) => tier(v.riskScore) === "low");

  const topCritical = critical.slice(0, 5);
  const topHigh = high.slice(0, 5);
  const topVendors = vendors.slice(0, 10);

  return (
    <main className="min-h-screen bg-slate-950 text-slate-50">
      <section className="max-w-6xl mx-auto px-4 py-10 space-y-10">
        {/* Header */}
        <header className="space-y-4">
          <p className="text-xs uppercase tracking-[0.25em] text-sky-400">
            Truvern · Board report
          </p>
          <h1 className="text-3xl md:text-4xl font-semibold">
            Third-party risk posture overview.
          </h1>
          <p className="text-sm md:text-base text-slate-300 max-w-3xl">
            This summary is designed for executives and boards. It pulls live
            data from Truvern&apos;s vendor and assessment tables and includes
            risk-based reassessment dates so you can show a clear plan for
            ongoing due diligence.
          </p>

          <div className="flex flex-wrap gap-3 pt-1">
            <Link
              href="/trust-network"
              className="inline-flex items-center rounded-md border border-slate-700 px-4 py-2 text-xs font-semibold text-slate-100 hover:border-sky-500 transition"
            >
              View Trust Network
            </Link>
            <Link
              href="/vendors"
              className="inline-flex items-center rounded-md border border-slate-700 px-4 py-2 text-xs font-semibold text-slate-100 hover:border-sky-500 transition"
            >
              Open Vendor Catalogue
            </Link>
          </div>
        </header>

        {/* Snapshot stats */}
        <section className="space-y-4">
          <h2 className="text-lg font-semibold">Network snapshot</h2>
          <div className="grid gap-4 md:grid-cols-4">
            <StatCard
              label="Vendors in scope"
              value={String(totalVendors)}
              helper="Total third parties with an active Truvern profile."
            />
            <StatCard
              label="Average risk score"
              value={String(avgRiskScore)}
              helper="0 (low) to 100 (high) aggregated across vendors."
            />
            <StatCard
              label="Assessment coverage"
              value={`${withAssessments.length}/${totalVendors || 0}`}
              helper={`Coverage: ${coverage}% have at least one assessment.`}
            />
            <StatCard
              label="High & critical vendors"
              value={`${high.length + critical.length}`}
              helper="Vendors that require heightened attention."
            />
          </div>
        </section>

        {/* Risk tier counts */}
        <section className="space-y-4">
          <h2 className="text-lg font-semibold">Risk tier overview</h2>
          <div className="grid gap-3 md:grid-cols-4">
            <TierCard
              label="Low risk"
              count={low.length}
              desc="Within appetite; monitor on a light cadence."
              tone="text-emerald-400"
            />
            <TierCard
              label="Medium risk"
              count={medium.length}
              desc="Normal exposure; reassess annually."
              tone="text-sky-300"
            />
            <TierCard
              label="High risk"
              count={high.length}
              desc="Material exposure; reassess at least twice per year."
              tone="text-amber-300"
            />
            <TierCard
              label="Critical"
              count={critical.length}
              desc="Outside appetite; requires executive oversight."
              tone="text-rose-400"
            />
          </div>
        </section>

        {/* Top vendor table with reassessment dates */}
        <section className="space-y-4">
          <div className="flex items-center justify-between gap-2">
            <h2 className="text-lg font-semibold">
              Key vendors & reassessment plan
            </h2>
            <p className="text-xs text-slate-400">
              Sorted by risk score. Reassessment due dates are driven by risk
              tier.
            </p>
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
                    Tier
                  </th>
                  <th className="px-4 py-2 text-left font-medium text-slate-300">
                    Last assessment
                  </th>
                  <th className="px-4 py-2 text-left font-medium text-slate-300">
                    Reassessment due
                  </th>
                </tr>
              </thead>
              <tbody>
                {topVendors.length === 0 && (
                  <tr>
                    <td
                      colSpan={5}
                      className="px-4 py-6 text-center text-sm text-slate-400"
                    >
                      No vendors available yet. Once assessments have been
                      completed, key vendors will appear here with
                      reassessment dates.
                    </td>
                  </tr>
                )}

                {topVendors.map((v) => {
                  const level = tier(v.riskScore);
                  const label =
                    level === "low"
                      ? "Low"
                      : level === "medium"
                      ? "Medium"
                      : level === "high"
                      ? "High"
                      : "Critical";

                  const tone =
                    level === "low"
                      ? "text-emerald-400 border-emerald-500/40"
                      : level === "medium"
                      ? "text-sky-300 border-sky-500/40"
                      : level === "high"
                      ? "text-amber-300 border-amber-400/40"
                      : "text-rose-400 border-rose-500/40";

                  const last = v.assessments?.[0];

                  return (
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
                      <td className="px-4 py-2">
                        <span
                          className={[
                            "inline-flex items-center rounded-full border px-2.5 py-0.5 text-xs font-medium",
                            tone,
                          ].join(" ")}
                        >
                          {label}
                        </span>
                      </td>
                      <td className="px-4 py-2 text-slate-400">
                        {formatDate(last?.createdAt ?? null)}
                      </td>
                      <td className="px-4 py-2 text-slate-200">
                        {calcReassessmentDate(v)}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </section>

        {/* Board templates section */}
        <section className="space-y-4">
          <h2 className="text-lg font-semibold">Board-ready templates</h2>
          <p className="text-sm text-slate-300 max-w-3xl">
            These templates describe different ways to lay out a board report
            using this same data. You can reference them directly in board
            materials (&quot;we are using the Heatmap template&quot;), or
            implement them as separate views in a future release.
          </p>

          <div className="grid gap-4 md:grid-cols-2">
            <TemplateCard
              name="Template 1 · Risk Heatmap"
              who="For audit & risk committees."
              layout="Opens with a one-slide heatmap of vendors grouped by tier, followed by a table of critical and high-risk vendors with reassessment dates."
            />
            <TemplateCard
              name="Template 2 · Executive Summary"
              who="For C-suite and CEO updates."
              layout="Starts with three key metrics (vendor count, coverage, high/critical vendors), then highlights the top 5 vendors that have changed tier since last meeting."
            />
            <TemplateCard
              name="Template 3 · Business Service View"
              who="For operations & business owners."
              layout="Groups vendors by the business service they support (payments, HR, data center) and shows risk score plus reassessment date per service."
            />
            <TemplateCard
              name="Template 4 · Remediation Tracker"
              who="For follow-up working sessions."
              layout="Focuses on high and critical vendors, showing open remediation items, latest assessment date, and when the next reassessment will confirm closure."
            />
            <TemplateCard
              name="Template 5 · Year-over-Year Trend"
              who="For annual board packs."
              layout="Summarizes how vendor counts, average risk, and assessment coverage have moved over the last four quarters, flagging any new critical vendors."
            />
          </div>
        </section>

        <footer className="pt-4 border-t border-slate-800 text-xs text-slate-500 space-y-1">
          <p>
            This view is intended as a live companion to static board decks.
            All figures refresh from the Truvern production database so you can
            reconcile any questions in real time during a meeting.
          </p>
        </footer>
      </section>
    </main>
  );
}

function StatCard(props: {
  label: string;
  value: string;
  helper?: string;
}) {
  const { label, value, helper } = props;
  return (
    <div className="rounded-lg border border-slate-800 bg-slate-900/40 p-4 space-y-1">
      <p className="text-xs font-medium text-slate-400 uppercase tracking-wide">
        {label}
      </p>
      <p className="text-2xl font-semibold text-slate-50">{value}</p>
      {helper && <p className="text-xs text-slate-400">{helper}</p>}
    </div>
  );
}

function TierCard(props: {
  label: string;
  count: number;
  desc: string;
  tone: string;
}) {
  const { label, count, desc, tone } = props;
  return (
    <div className="rounded-lg border border-slate-800 bg-slate-900/40 p-4 space-y-2">
      <p className="text-xs font-medium text-slate-400 uppercase tracking-wide">
        {label}
      </p>
      <p className={`text-2xl font-semibold ${tone}`}>{count}</p>
      <p className="text-xs text-slate-400">{desc}</p>
    </div>
  );
}

function TemplateCard(props: {
  name: string;
  who: string;
  layout: string;
}) {
  const { name, who, layout } = props;
  return (
    <div className="rounded-lg border border-slate-800 bg-slate-900/40 p-4 space-y-2 text-sm">
      <p className="font-semibold text-slate-100">{name}</p>
      <p className="text-xs text-slate-400">{who}</p>
      <p className="text-slate-200">{layout}</p>
    </div>
  );
}
'@

Set-Content -Path $pagePath -Value $pageContent -Encoding UTF8
Write-Host "[INFO] Wrote upgraded reports/board/page.tsx" -ForegroundColor Green

# 4) Trigger cloud deploy so changes go live
$deployScript = Join-Path $root "Phase132g-CloudDeploy.ps1"
if (Test-Path $deployScript) {
    Write-Host "[STEP] Running Phase132g-CloudDeploy.ps1..." -ForegroundColor Cyan
    & $deployScript
} else {
    Write-Host "[STEP] Running 'vercel --prod --yes' (fallback)..." -ForegroundColor Cyan
    vercel --prod --yes
}

Write-Host "=== Phase140-BoardReportUpgrade complete ===" -ForegroundColor Cyan
