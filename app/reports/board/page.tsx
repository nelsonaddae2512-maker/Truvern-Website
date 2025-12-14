// app/reports/board/page.tsx
import { notFound } from "next/navigation";
import prisma from "@/lib/prisma";

type BoardSnapshot = {
  metrics: {
    totalVendors: number;
    avgRiskScore: number | null;
    vendorsByTier: Record<string, number>;
    vendorsByCriticality: Record<string, number>;
    totalEvidence: number;
    totalAssessments: number;
    completedAssessments: number;
    totalIssues: number;
    openIssues: number;
    openIssuesBySeverity: Record<string, number>;
    trustNetworkSize: number;
  };
  vendors: {
    id: number;
    name: string;
    slug: string;
    tier: string | null;
    criticality: string | null;
    riskScore: number | null;
    openIssues: number;
    evidenceCount: number;
    lastAssessmentAt: Date | null;
  }[];
};

async function getBoardSnapshot(): Promise<BoardSnapshot | null> {
  const org = await prisma.organization.findFirst({
    where: { slug: "acme-security" },
  });

  if (!org) return null;

  const vendors = await prisma.vendor.findMany({
    where: { organizationId: org.id },
    include: {
      issues: true,
      evidence: true,
      assessments: true,
    },
    orderBy: { name: "asc" },
  });

  const trustNetworkSize = await prisma.trustProfile.count({
    where: {
      organizationId: org.id,
      isPublic: true,
    },
  });

  if (!vendors.length) {
    return {
      metrics: {
        totalVendors: 0,
        avgRiskScore: null,
        vendorsByTier: {},
        vendorsByCriticality: {},
        totalEvidence: 0,
        totalAssessments: 0,
        completedAssessments: 0,
        totalIssues: 0,
        openIssues: 0,
        openIssuesBySeverity: {},
        trustNetworkSize,
      },
      vendors: [],
    };
  }

  let riskSum = 0;
  let riskCount = 0;

  const vendorsByTier: Record<string, number> = {};
  const vendorsByCriticality: Record<string, number> = {};
  const openIssuesBySeverity: Record<string, number> = {};

  let totalEvidence = 0;
  let totalAssessments = 0;
  let completedAssessments = 0;
  let totalIssues = 0;
  let openIssues = 0;

  const vendorRows = vendors.map((v) => {
    // risk
    if (typeof v.riskScore === "number") {
      riskSum += v.riskScore;
      riskCount += 1;
    }

    // tier
    if (v.tier) {
      vendorsByTier[v.tier] = (vendorsByTier[v.tier] || 0) + 1;
    }

    // criticality
    if (v.criticality) {
      vendorsByCriticality[v.criticality] =
        (vendorsByCriticality[v.criticality] || 0) + 1;
    }

    // issues
    totalIssues += v.issues.length;
    const vendorOpenIssues = v.issues.filter(
      (i) => i.status !== "RESOLVED" && i.status !== "ACCEPTED_RISK"
    );
    openIssues += vendorOpenIssues.length;

    vendorOpenIssues.forEach((issue) => {
      const sev = issue.severity || "UNSPECIFIED";
      openIssuesBySeverity[sev] = (openIssuesBySeverity[sev] || 0) + 1;
    });

    // evidence
    totalEvidence += v.evidence.length;

    // assessments
    totalAssessments += v.assessments.length;
    const completedForVendor = v.assessments.filter((a) => a.completedAt);
    completedAssessments += completedForVendor.length;

    const lastAssessmentAt =
      completedForVendor
        .sort(
          (a, b) =>
            new Date(b.completedAt!).getTime() -
            new Date(a.completedAt!).getTime()
        )[0]?.completedAt ?? null;

    return {
      id: v.id,
      name: v.name,
      slug: v.slug,
      tier: v.tier,
      criticality: v.criticality,
      riskScore: v.riskScore as number | null,
      openIssues: vendorOpenIssues.length,
      evidenceCount: v.evidence.length,
      lastAssessmentAt,
    };
  });

  const avgRiskScore = riskCount ? Math.round(riskSum / riskCount) : null;

  return {
    metrics: {
      totalVendors: vendors.length,
      avgRiskScore,
      vendorsByTier,
      vendorsByCriticality,
      totalEvidence,
      totalAssessments,
      completedAssessments,
      totalIssues,
      openIssues,
      openIssuesBySeverity,
      trustNetworkSize,
    },
    vendors: vendorRows,
  };
}

function renderDistribution(
  data: Record<string, number>,
  emptyLabel: string
) {
  const entries = Object.entries(data);
  if (!entries.length) {
    return <span className="text-xs text-slate-400">{emptyLabel}</span>;
  }

  return (
    <div className="flex flex-wrap gap-2 text-xs">
      {entries.map(([label, count]) => (
        <span
          key={label}
          className="rounded-full border border-slate-700 px-2 py-0.5"
        >
          {label}: {count}
        </span>
      ))}
    </div>
  );
}

function buildBoardMarkdown(snapshot: BoardSnapshot): string {
  const { metrics, vendors } = snapshot;
  const today = new Date().toISOString().slice(0, 10);

  const avgScoreText =
    typeof metrics.avgRiskScore === "number"
      ? `${metrics.avgRiskScore}/100`
      : "Not yet scored";

  const topAttention = vendors
    .slice() // shallow copy
    .sort((a, b) => {
      // sort: most open issues first, then lowest risk score
      if (b.openIssues !== a.openIssues) {
        return b.openIssues - a.openIssues;
      }
      const ar = typeof a.riskScore === "number" ? a.riskScore : 999;
      const br = typeof b.riskScore === "number" ? b.riskScore : 999;
      return ar - br;
    })
    .slice(0, 3);

  const attentionLines =
    topAttention.length === 0
      ? "- No vendors flagged for special attention at this time."
      : topAttention
          .map((v) => {
            const score =
              typeof v.riskScore === "number" ? `${v.riskScore}/100` : "n/a";
            const issues =
              v.openIssues > 0 ? `${v.openIssues} open issues` : "no open issues";
            const last =
              v.lastAssessmentAt != null
                ? new Date(v.lastAssessmentAt).toLocaleDateString()
                : "no completed assessment";
            return `- **${v.name}** – health ${score}, ${issues}, last assessment ${last}`;
          })
          .join("\n");

  return [
    `## Truvern board snapshot – ${today}`,
    "",
    "**Portfolio overview**",
    `- Vendors in scope: ${metrics.totalVendors}`,
    `- Public trust profiles: ${metrics.trustNetworkSize}`,
    `- Average vendor health score: ${avgScoreText}`,
    "",
    "**Issues & assessments**",
    `- Open issues: ${metrics.openIssues} (of ${metrics.totalIssues} total)`,
    `- Evidence items on file: ${metrics.totalEvidence}`,
    `- Completed assessments: ${metrics.completedAssessments} of ${metrics.totalAssessments} total`,
    "",
    "**Top attention vendors**",
    attentionLines,
    "",
    "_Source: Truvern live data_",
  ].join("\n");
}

export default async function BoardReportPage() {
  const snapshot = await getBoardSnapshot();
  if (!snapshot) {
    notFound();
  }

  const { metrics, vendors } = snapshot;
  const markdown = buildBoardMarkdown(snapshot);

  return (
    <main className="truvern-shell">
      {/* Header */}
      <header className="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
        <div>
          <p className="text-xs font-medium tracking-wide text-emerald-400">
            Truvern Board Report
          </p>
          <h1 className="truvern-page-heading">Third-Party Risk Overview</h1>
          <p className="truvern-page-subheading">
            High-level view of Acme Security&apos;s third-party risk posture,
            powered by live Truvern data across vendors, assessments, evidence,
            and issues.
          </p>
        </div>

        <div className="flex flex-col items-start gap-3 md:items-end">
          {/* Average health pill */}
          <div className="truvern-card px-4 py-3">
            <div className="text-xs text-slate-400">Average vendor health</div>
            {typeof metrics.avgRiskScore === "number" ? (
              <div className="mt-1 inline-flex items-center gap-2">
                <span className="h-2 w-2 rounded-full bg-emerald-400" />
                <span className="text-lg font-semibold">
                  {metrics.avgRiskScore}/100
                </span>
              </div>
            ) : (
              <div className="mt-1 text-xs text-slate-400">
                Not yet scored
              </div>
            )}
          </div>

          {/* Download CSV button */}
          <a
            href="/api/reports/board/csv"
            className="btn-outline"
            target="_blank"
            rel="noopener noreferrer"
          >
            Download CSV
          </a>
        </div>
      </header>

      {/* KPI strip */}
      <section className="grid gap-3 md:grid-cols-4">
        <div className="truvern-card">
          <div className="text-xs text-slate-400">Total vendors</div>
          <div className="mt-1 text-2xl font-semibold">
            {metrics.totalVendors}
          </div>
        </div>
        <div className="truvern-card">
          <div className="text-xs text-slate-400">Open issues</div>
          <div className="mt-1 text-2xl font-semibold text-amber-300">
            {metrics.openIssues}
          </div>
          <div className="mt-2 text-[11px] text-slate-400">
            {metrics.totalIssues} total issues tracked
          </div>
        </div>
        <div className="truvern-card">
          <div className="text-xs text-slate-400">Evidence on file</div>
          <div className="mt-1 text-2xl font-semibold">
            {metrics.totalEvidence}
          </div>
        </div>
        <div className="truvern-card">
          <div className="text-xs text-slate-400">Public trust profiles</div>
          <div className="mt-1 text-2xl font-semibold">
            {metrics.trustNetworkSize}
          </div>
        </div>
      </section>

      {/* NEW: Board snapshot markdown */}
      <section className="truvern-card">
        <div className="truvern-card-header">
          <h2 className="truvern-card-title">Board snapshot (markdown)</h2>
          <p className="text-xs text-slate-400">
            Copy/paste this block into an email or slide to brief the board.
          </p>
        </div>
        <textarea
          readOnly
          className="mt-2 h-56 w-full resize-none rounded-lg border border-slate-800 bg-slate-950/80 p-3 text-xs font-mono text-slate-100"
          spellCheck={false}
          value={markdown}
        />
      </section>

      {/* Distributions */}
      <section className="grid gap-4 md:grid-cols-2">
        <div className="truvern-card">
          <div className="truvern-card-header">
            <h2 className="truvern-card-title">Vendors by tier</h2>
          </div>
          {renderDistribution(metrics.vendorsByTier, "No tier data yet.")}
        </div>

        <div className="truvern-card">
          <div className="truvern-card-header">
            <h2 className="truvern-card-title">Vendors by criticality</h2>
          </div>
          {renderDistribution(
            metrics.vendorsByCriticality,
            "No criticality data yet."
          )}
        </div>
      </section>

      {/* Issues severity breakdown & assessments */}
      <section className="grid gap-4 md:grid-cols-2">
        <div className="truvern-card">
          <div className="truvern-card-header">
            <h2 className="truvern-card-title">Open issues by severity</h2>
          </div>
          {renderDistribution(
            metrics.openIssuesBySeverity,
            "No open issues at this time."
          )}
        </div>

        <div className="truvern-card">
          <div className="truvern-card-header">
            <h2 className="truvern-card-title">Assessments summary</h2>
          </div>
          <div className="space-y-2 text-sm text-slate-200">
            <div>
              <span className="text-slate-400">Total assessments: </span>
              <span className="font-semibold">
                {metrics.totalAssessments}
              </span>
            </div>
            <div>
              <span className="text-slate-400">Completed assessments: </span>
              <span className="font-semibold">
                {metrics.completedAssessments}
              </span>
            </div>
          </div>
        </div>
      </section>

      {/* Vendor table */}
      <section className="truvern-card">
        <div className="truvern-card-header">
          <h2 className="truvern-card-title">Vendor detail</h2>
          <p className="text-xs text-slate-400">
            Highest-risk vendors float to the top based on open issues and
            health score.
          </p>
        </div>

        {vendors.length === 0 ? (
          <p className="text-sm text-slate-400">
            No vendors yet. Once vendors are added and assessed, they will
            appear here.
          </p>
        ) : (
          <table className="truvern-table">
            <thead>
              <tr>
                <th>Vendor</th>
                <th className="hidden md:table-cell">Tier</th>
                <th className="hidden md:table-cell">Criticality</th>
                <th>Health</th>
                <th>Open issues</th>
                <th className="hidden md:table-cell">Evidence</th>
                <th className="hidden md:table-cell">Last assessment</th>
              </tr>
            </thead>
            <tbody>
              {vendors.map((v) => (
                <tr key={v.id}>
                  <td>
                    <a
                      href={`/vendors/${v.slug}`}
                      className="font-medium text-slate-50 hover:text-emerald-400"
                    >
                      {v.name}
                    </a>
                  </td>
                  <td className="hidden md:table-cell text-slate-300">
                    {v.tier ?? "—"}
                  </td>
                  <td className="hidden md:table-cell text-slate-300">
                    {v.criticality ?? "—"}
                  </td>
                  <td>
                    {typeof v.riskScore === "number" ? (
                      <span className="inline-flex items-center rounded-full bg-slate-900 px-2 py-0.5 text-xs">
                        <span className="mr-1 h-1.5 w-1.5 rounded-full bg-emerald-400" />
                        {v.riskScore}/100
                      </span>
                    ) : (
                      <span className="text-xs text-slate-400">Not scored</span>
                    )}
                  </td>
                  <td>
                    {v.openIssues > 0 ? (
                      <span className="text-xs text-amber-300">
                        {v.openIssues} open
                      </span>
                    ) : (
                      <span className="text-xs text-slate-400">None</span>
                    )}
                  </td>
                  <td className="hidden md:table-cell text-xs text-slate-300">
                    {v.evidenceCount}
                  </td>
                  <td className="hidden md:table-cell text-xs text-slate-300">
                    {v.lastAssessmentAt
                      ? new Date(v.lastAssessmentAt).toLocaleDateString()
                      : "—"}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </section>
    </main>
  );
}
