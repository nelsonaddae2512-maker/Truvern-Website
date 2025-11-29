$ErrorActionPreference = "Stop"

Write-Host "=== Phase137: Trust Network Upgrade ===" -ForegroundColor Cyan

# Always work from the project directory
$root = $PSScriptRoot
Set-Location $root
Write-Host "[INFO] Working in: $root" -ForegroundColor DarkCyan

# Paths
$trustDir = Join-Path $root "app\trust-network"
$pagePath = Join-Path $trustDir "page.tsx"

# 1) Ensure app/trust-network directory exists
if (-not (Test-Path $trustDir)) {
    New-Item -ItemType Directory -Path $trustDir | Out-Null
    Write-Host "[INFO] Created app/trust-network directory." -ForegroundColor Yellow
} else {
    Write-Host "[INFO] app/trust-network directory already exists." -ForegroundColor DarkYellow
}

# 2) Backup existing page.tsx if it exists
if (Test-Path $pagePath) {
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupPath = "$pagePath.bak-$stamp"
    Copy-Item $pagePath $backupPath
    Write-Host "[INFO] Backed up existing trust-network/page.tsx to: $backupPath" -ForegroundColor DarkYellow
}

# 3) Write new trust-network/page.tsx
$pageContent = @'
import Link from "next/link";
import { prisma } from "@/lib/prisma";

export const dynamic = "force-dynamic";

function tier(score: number): "low" | "medium" | "high" | "critical" {
  if (score >= 80) return "critical";
  if (score >= 60) return "high";
  if (score >= 40) return "medium";
  return "low";
}

type TrustVendor = {
  id: number;
  name: string;
  riskScore: number;
  assessments: { createdAt: Date }[];
};

function formatLatestAssessment(v: TrustVendor): string {
  const latest = v.assessments?.[0];
  if (!latest) return "No assessments yet";

  const d = new Date(latest.createdAt);
  if (Number.isNaN(d.getTime())) return "No assessments yet";

  return d.toLocaleDateString();
}

function StatPill(props: { label: string; value: string; helper?: string }) {
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

export default async function TrustNetworkPage() {
  const vendors = (await prisma.vendor.findMany({
    orderBy: { riskScore: "desc" },
    include: {
      assessments: {
        orderBy: { createdAt: "desc" },
        take: 1,
      },
    },
  })) as TrustVendor[];

  const totalVendors = vendors.length;
  const avgRiskScore =
    totalVendors === 0
      ? 0
      : Math.round(
          vendors.reduce((sum, v) => sum + (v.riskScore || 0), 0) /
            totalVendors
        );

  const low = vendors.filter((v) => tier(v.riskScore) === "low");
  const medium = vendors.filter((v) => tier(v.riskScore) === "medium");
  const high = vendors.filter((v) => tier(v.riskScore) === "high");
  const critical = vendors.filter((v) => tier(v.riskScore) === "critical");

  const withAssessments = vendors.filter((v) => v.assessments.length > 0);
  const coverage =
    totalVendors === 0
      ? 0
      : Math.round((withAssessments.length / totalVendors) * 100);

  const featured = vendors.slice(0, 6);

  return (
    <main className="min-h-screen bg-slate-950 text-slate-50">
      <section className="max-w-6xl mx-auto px-4 py-10 space-y-10">
        {/* Hero */}
        <header className="space-y-4">
          <p className="text-xs uppercase tracking-[0.25em] text-sky-400">
            Truvern · Third-party risk network
          </p>
          <h1 className="text-3xl md:text-4xl font-semibold">
            One network to prove and share vendor trust.
          </h1>
          <p className="text-sm md:text-base text-slate-300 max-w-3xl">
            Truvern connects your vendors, assessments, and evidence into a live
            trust network. Instead of spreadsheets and one-off questionnaires,
            you get reusable vendor profiles and a board-ready view of risk.
          </p>

          <div className="flex flex-wrap gap-3 pt-2">
            <Link
              href="/reports/board"
              className="inline-flex items-center rounded-md bg-sky-500 px-4 py-2 text-sm font-semibold text-slate-950 hover:bg-sky-400 transition"
            >
              View board report
            </Link>
            <Link
              href="/vendors"
              className="inline-flex items-center rounded-md border border-slate-700 px-4 py-2 text-sm font-semibold text-slate-100 hover:border-sky-500 transition"
            >
              Browse vendor catalogue
            </Link>
          </div>
        </header>

        {/* Network stats */}
        <section className="space-y-4">
          <h2 className="text-lg font-semibold">Network health snapshot</h2>
          <div className="grid gap-4 md:grid-cols-3">
            <StatPill
              label="Vendors in network"
              value={String(totalVendors)}
              helper="Active third parties with a Truvern profile."
            />
            <StatPill
              label="Average risk score"
              value={String(avgRiskScore)}
              helper="0 (lowest) to 100 (highest) risk."
            />
            <StatPill
              label="Vendors with assessments"
              value={`${withAssessments.length}/${totalVendors || 0}`}
              helper={`Coverage: ${coverage}% have at least one assessment.`}
            />
          </div>
        </section>

        {/* Risk tiers */}
        <section className="space-y-4">
          <h2 className="text-lg font-semibold">Risk tier distribution</h2>
          <div className="grid gap-3 md:grid-cols-2">
            <div className="rounded-lg border border-slate-800 bg-slate-900/40 p-4 space-y-3">
              <TierRow
                label="Low risk"
                count={low.length}
                tone="text-emerald-400"
                helper="Within appetite; standard monitoring."
              />
              <TierRow
                label="Medium risk"
                count={medium.length}
                tone="text-sky-300"
                helper="Requires normal oversight and periodic reassessment."
              />
              <TierRow
                label="High risk"
                count={high.length}
                tone="text-amber-300"
                helper="Heightened exposure; additional controls recommended."
              />
              <TierRow
                label="Critical"
                count={critical.length}
                tone="text-rose-400"
                helper="Outside risk appetite; requires executive attention."
              />
            </div>

            <div className="rounded-lg border border-slate-800 bg-slate-900/40 p-4 space-y-2 text-sm text-slate-300">
              <p className="font-medium text-slate-100">
                How the Trust Network is calculated
              </p>
              <p>
                Each vendor is assigned a risk score based on recent
                assessments. Scores are grouped into low, medium, high, and
                critical tiers to make the overall posture easy to explain to
                executives and boards.
              </p>
              <p className="text-xs text-slate-400">
                Thresholds (configurable in future phases): 0–39 low, 40–59
                medium, 60–79 high, 80–100 critical.
              </p>
            </div>
          </div>
        </section>

        {/* Featured vendors */}
        <section className="space-y-4">
          <div className="flex items-center justify-between gap-2">
            <h2 className="text-lg font-semibold">Featured vendors</h2>
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
                    Tier
                  </th>
                  <th className="px-4 py-2 text-left font-medium text-slate-300">
                    Latest assessment
                  </th>
                </tr>
              </thead>
              <tbody>
                {featured.length === 0 && (
                  <tr>
                    <td
                      colSpan={4}
                      className="px-4 py-6 text-center text-sm text-slate-400"
                    >
                      No vendors available yet. Once vendors are onboarded, a
                      sampled set will appear here.
                    </td>
                  </tr>
                )}
                {featured.map((v) => {
                  const t = tier(v.riskScore);
                  const tierLabel =
                    t === "low"
                      ? "Low"
                      : t === "medium"
                      ? "Medium"
                      : t === "high"
                      ? "High"
                      : "Critical";

                  const tierTone =
                    t === "low"
                      ? "text-emerald-400 border-emerald-500/40"
                      : t === "medium"
                      ? "text-sky-300 border-sky-500/40"
                      : t === "high"
                      ? "text-amber-300 border-amber-400/40"
                      : "text-rose-400 border-rose-500/40";

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
                            tierTone,
                          ].join(" ")}
                        >
                          {tierLabel}
                        </span>
                      </td>
                      <td className="px-4 py-2 text-slate-400">
                        {formatLatestAssessment(v)}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </section>

        {/* Footer / reassurance */}
        <footer className="pt-4 border-t border-slate-800 text-xs text-slate-500">
          <p>
            This Trust Network view is derived from your production Vendor and
            Assessment data in Truvern. It is safe to share with stakeholders
            as a high-level summary of third-party risk posture.
          </p>
        </footer>
      </section>
    </main>
  );
}

function TierRow(props: {
  label: string;
  count: number;
  tone: string;
  helper: string;
}) {
  const { label, count, tone, helper } = props;
  return (
    <div className="flex items-center justify-between rounded-md border border-slate-800 bg-slate-950/60 px-4 py-3">
      <div className="space-y-1">
        <p className="text-sm font-medium text-slate-100">{label}</p>
        <p className="text-xs text-slate-400">{helper}</p>
      </div>
      <span className={`text-2xl font-semibold ${tone}`}>{count}</span>
    </div>
  );
}
'@

Set-Content -Path $pagePath -Value $pageContent -Encoding UTF8
Write-Host "[INFO] Wrote upgraded trust-network/page.tsx" -ForegroundColor Green

# 4) Trigger cloud deploy
$deployScript = Join-Path $root "Phase132g-CloudDeploy.ps1"
if (Test-Path $deployScript) {
    Write-Host "[STEP] Running Phase132g-CloudDeploy.ps1..." -ForegroundColor Cyan
    & $deployScript
} else {
    Write-Host "[STEP] Running 'vercel --prod --yes' (fallback)..." -ForegroundColor Cyan
    vercel --prod --yes
}

Write-Host "=== Phase137-TrustNetworkEnhance complete ===" -ForegroundColor Cyan
