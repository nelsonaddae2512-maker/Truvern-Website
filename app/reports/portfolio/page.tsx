// app/reports/portfolio/page.tsx

import Link from "next/link";
import prisma from "@/lib/prisma";

const HIGH_RISK_THRESHOLD = 85;
const CRITICAL_STALE_THRESHOLD = 90;
const STALE_DAYS = 365;

type PortfolioStats = {
  vendorCount: number;
  avgHealth: number;
  evidenceItems: number;
  cia: {
    confidentiality: number;
    integrity: number;
    availability: number;
  };
};

type AlertItem = {
  vendorId: number;
  vendorName: string;
  severity: "high" | "medium" | "info";
  code:
    | "HIGH_RISK"
    | "MISSING_EVIDENCE"
    | "NO_ASSESSMENTS"
    | "STALE_ASSESSMENTS";
  message: string;
};

type AlertSummary = {
  highRiskVendors: number;
  vendorsMissingEvidence: number;
  vendorsWithoutAssessments: number;
  staleCriticalVendors: number;
};

type VendorWithCounts = {
  id: number;
  name: string;
  riskScore: number | null;
  _count: {
    assessments: number;
    evidence: number;
  };
};

type ActivityItem = {
  vendorId: number;
  vendorName: string;
  kind: "evidence" | "assessment";
  label: string;
  timestamp: Date;
  accent: string;
};

async function getPortfolioData(): Promise<{
  stats: PortfolioStats;
  alertSummary: AlertSummary;
  alertItems: AlertItem[];
  topVendors: VendorWithCounts[];
  activityFeed: ActivityItem[];
}> {
  // --- PORTFOLIO STATS ---
  const vendorCount = await prisma.vendor.count();

  const healthAgg = await prisma.vendor.aggregate({
    _avg: { riskScore: true },
  });

  const avgHealthRaw = healthAgg._avg.riskScore ?? 0;
  const avgHealth = Math.round(avgHealthRaw);

  const evidenceItems = await prisma.evidence.count();

  const normalizedHealth = Math.max(
    0,
    Math.min(100, Number.isNaN(avgHealth) ? 0 : avgHealth)
  );

  const stats: PortfolioStats = {
    vendorCount,
    avgHealth,
    evidenceItems,
    cia: {
      confidentiality: Math.max(0, Math.min(100, normalizedHealth + 2)),
      integrity: Math.max(0, Math.min(100, normalizedHealth)),
      availability: Math.max(0, Math.min(100, normalizedHealth - 2)),
    },
  };

  // --- RULE ENGINE INPUT: vendors that might need alerts ---
  const now = new Date();
  const staleCutoff = new Date(
    now.getTime() - STALE_DAYS * 24 * 60 * 60 * 1000
  );

  const vendorsForAlerts = await prisma.vendor.findMany({
    where: {
      OR: [
        { riskScore: { gte: HIGH_RISK_THRESHOLD } }, // high risk
        { evidence: { none: {} } }, // missing evidence
        { assessments: { none: {} } }, // no assessments
        {
          AND: [
            { riskScore: { gte: CRITICAL_STALE_THRESHOLD } },
            {
              assessments: {
                some: {},
              },
            },
          ],
        }, // candidate set for stale assessments
      ],
    },
    include: {
      _count: {
        select: {
          assessments: true,
          evidence: true,
        },
      },
      assessments: {
        select: { createdAt: true },
        orderBy: { createdAt: "desc" },
        take: 1,
      },
    },
  });

  // --- RULE ENGINE: generate vendor-level alert items ---
  const alertItems: AlertItem[] = [];

  for (const v of vendorsForAlerts) {
    const score = v.riskScore ?? 0;
    const lastAssessmentDate = v.assessments[0]?.createdAt;

    // Rule 1: High risk vendors
    if (score >= HIGH_RISK_THRESHOLD) {
      alertItems.push({
        vendorId: v.id,
        vendorName: v.name,
        severity: "high",
        code: "HIGH_RISK",
        message: `High risk score (${score}). Prioritize review.`,
      });
    }

    // Rule 2: Missing evidence — treated as HIGH severity
    if (v._count.evidence === 0) {
      alertItems.push({
        vendorId: v.id,
        vendorName: v.name,
        severity: "high",
        code: "MISSING_EVIDENCE",
        message: "No supporting evidence on file.",
      });
    }

    // Rule 3: No assessments
    if (v._count.assessments === 0) {
      alertItems.push({
        vendorId: v.id,
        vendorName: v.name,
        severity: "medium",
        code: "NO_ASSESSMENTS",
        message: "No assessments completed yet.",
      });
    }

    // Rule 4: Critical vendors with stale assessments
    if (
      score >= CRITICAL_STALE_THRESHOLD &&
      lastAssessmentDate &&
      lastAssessmentDate < staleCutoff
    ) {
      const lastReviewed = lastAssessmentDate.toLocaleDateString();
      alertItems.push({
        vendorId: v.id,
        vendorName: v.name,
        severity: "high",
        code: "STALE_ASSESSMENTS",
        message: `Critical vendor with stale assessment (last reviewed ${lastReviewed}).`,
      });
    }
  }

  // --- SUMMARY COUNTS (driven by the same rules) ---
  const uniqVendorCountByCode = (code: AlertItem["code"]) =>
    new Set(alertItems.filter((a) => a.code === code).map((a) => a.vendorId))
      .size;

  const alertSummary: AlertSummary = {
    highRiskVendors: uniqVendorCountByCode("HIGH_RISK"),
    vendorsMissingEvidence: uniqVendorCountByCode("MISSING_EVIDENCE"),
    vendorsWithoutAssessments: uniqVendorCountByCode("NO_ASSESSMENTS"),
    staleCriticalVendors: uniqVendorCountByCode("STALE_ASSESSMENTS"),
  };

  // --- TOP 10 RISKIEST VENDORS ---
  const topVendors = await prisma.vendor.findMany({
    orderBy: { riskScore: "desc" },
    take: 10,
    include: {
      _count: {
        select: {
          assessments: true,
          evidence: true,
        },
      },
    },
  });

  // --- MINI ACTIVITY FEED (recent evidence + assessments) ---
  // 🔧 FIX: use uploadedAt instead of createdAt for Evidence
  const recentEvidence = await prisma.evidence.findMany({
    orderBy: { uploadedAt: "desc" },
    take: 6,
    include: {
      vendor: {
        select: { id: true, name: true },
      },
    },
  });

  const recentAssessments = await prisma.assessment.findMany({
    orderBy: { createdAt: "desc" },
    take: 6,
    include: {
      vendor: {
        select: { id: true, name: true },
      },
    },
  });

  const activityItems: ActivityItem[] = [
    ...recentEvidence
      .filter((e) => e.vendor)
      .map((e) => ({
        vendorId: e.vendor!.id,
        vendorName: e.vendor!.name,
        kind: "evidence" as const,
        label: e.title || "New evidence added",
        timestamp: e.uploadedAt ?? new Date(),
        accent: e.kind || "Evidence",
      })),
    ...recentAssessments
      .filter((a) => a.vendor)
      .map((a) => ({
        vendorId: a.vendor!.id,
        vendorName: a.vendor!.name,
        kind: "assessment" as const,
        label: "Assessment updated",
        timestamp: a.createdAt,
        accent: "Assessment",
      })),
  ];

  activityItems.sort(
    (a, b) => a.timestamp.getTime() - b.timestamp.getTime()
  );

  const activityFeed = activityItems.slice(0, 8);

  return { stats, alertSummary, alertItems, topVendors, activityFeed };
}

function formatShortDate(d: Date) {
  return d.toLocaleDateString(undefined, {
    month: "short",
    day: "numeric",
  });
}

export const metadata = {
  title: "Vendor Portfolio Dashboard – Truvern",
  description:
    "Portfolio-level view of your third-party risk posture across all vendors.",
};

export default async function PortfolioDashboardPage() {
  const { stats, alertSummary, alertItems, topVendors, activityFeed } =
    await getPortfolioData();

  const visibleAlerts = alertItems.slice(0, 10);

  return (
    <main className="relative max-w-6xl mx-auto px-4 lg:px-6 py-12 lg:py-16">
      {/* Soft Truvern background glows */}
      <div className="pointer-events-none absolute inset-x-0 -top-32 -z-10 h-64 bg-[radial-gradient(circle_at_top,_rgba(45,212,191,0.25),transparent_60%)]" />
      <div className="pointer-events-none absolute inset-x-0 bottom-0 -z-10 h-64 bg-[radial-gradient(circle_at_bottom,_rgba(56,189,248,0.20),transparent_60%)]" />

      {/* Accent line */}
      <div className="h-px w-full bg-gradient-to-r from-emerald-400/80 via-cyan-400/70 to-violet-500/70 mb-3" />

      {/* Tiny print-layout banner */}
      <div className="mb-6">
        <div className="flex flex-wrap items-center justify-between gap-2 rounded-2xl border border-slate-800/80 bg-slate-950/70 px-3 py-2 text-[11px] text-slate-300">
          <span className="flex items-center gap-2">
            <span className="inline-flex h-4 w-7 items-center justify-center rounded-full border border-slate-700 bg-slate-900/70 text-[9px] uppercase tracking-[0.18em] text-slate-400">
              View
            </span>
            <span>
              Prefer a clean{" "}
              <span className="font-semibold text-slate-100">
                print layout
              </span>{" "}
              for the board?
            </span>
          </span>
          <Link
            href="/board-report"
            className="inline-flex items-center gap-1 rounded-full border border-emerald-500/60 bg-emerald-500/10 px-3 py-1 text-[11px] font-medium text-emerald-200 hover:bg-emerald-500/20"
          >
            <span>Open board report view</span>
            <span>↗</span>
          </Link>
        </div>
      </div>

      {/* HERO / HEADER */}
      <section className="flex flex-col gap-6 lg:flex-row lg:items-center lg:justify-between">
        <div className="space-y-4">
          <div className="inline-flex items-center gap-2 rounded-full bg-slate-900/70 border border-emerald-500/30 px-3 py-1">
            <span className="h-1.5 w-1.5 rounded-full bg-emerald-400 animate-pulse" />
            <span className="text-[10px] font-semibold tracking-[0.2em] text-emerald-300 uppercase">
              Truvern live portfolio
            </span>
          </div>

          <div>
            <h1 className="text-3xl lg:text-4xl font-semibold text-slate-50 tracking-tight">
              Vendor Portfolio Dashboard
            </h1>
            <p className="mt-3 max-w-2xl text-slate-300 text-sm lg:text-base">
              A friendly, executive-ready view of your third-party landscape.
              See where you&apos;re healthy, where you&apos;re exposed, and
              which vendors deserve a closer look next.
            </p>
          </div>

          <div className="flex flex-wrap gap-3">
            <Link
              href="/api/reports/portfolio.csv"
              className="inline-flex items-center gap-2 rounded-full border border-slate-700 bg-slate-950/70 px-4 py-2 text-sm font-medium text-slate-100 hover:border-emerald-400/60 hover:bg-slate-900/80 transition"
            >
              <span className="text-xs">⬇</span>
              <span>Download CSV</span>
            </Link>
            <Link
              href="/api/reports/portfolio.pdf"
              className="inline-flex items-center gap-2 rounded-full bg-emerald-500 px-4 py-2 text-sm font-semibold text-slate-950 shadow-md shadow-emerald-500/40 hover:bg-emerald-400 transition"
            >
              <span className="text-xs">📊</span>
              <span>Executive PDF</span>
            </Link>
          </div>
        </div>

        <div className="rounded-3xl bg-slate-900/70 border border-slate-700/70 px-4 py-4 lg:px-5 lg:py-5 shadow-lg shadow-black/40 max-w-xs lg:max-w-sm">
          <p className="text-[11px] font-semibold tracking-wide text-slate-400 uppercase">
            Today&apos;s posture snapshot
          </p>
          <div className="mt-3 space-y-2 text-sm">
            <div className="flex items-center justify-between">
              <span className="text-slate-400">Vendors in scope</span>
              <span className="font-semibold text-slate-50">
                {stats.vendorCount}
              </span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-slate-400">Average health</span>
              <span className="font-semibold text-emerald-300">
                {Number.isNaN(stats.avgHealth) ? "—" : stats.avgHealth}
              </span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-slate-400">Evidence items</span>
              <span className="font-semibold text-sky-300">
                {stats.evidenceItems}
              </span>
            </div>
          </div>
          <p className="mt-3 text-[11px] text-slate-500">
            Powered by your real vendor data — refreshed as you add assessments
            and evidence.
          </p>
        </div>
      </section>

      {/* ALERT STRIP – EXECUTIVE AT-A-GLANCE */}
      <section className="mt-10">
        <div className="rounded-3xl border border-emerald-500/40 bg-gradient-to-r from-slate-950/90 via-slate-900/90 to-slate-950/90 px-4 py-4 lg:px-5 lg:py-5 shadow-[0_18px_60px_rgba(0,0,0,0.70)]">
          {/* SUMMARY ROW */}
          <div className="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
            <div>
              <p className="text-[11px] font-semibold uppercase tracking-[0.18em] text-emerald-300">
                Portfolio alerts
              </p>
              <p className="mt-1 text-sm text-slate-300 max-w-xl">
                Truvern&apos;s rules quietly scan your vendor set and surface a
                calm, prioritized list of where to look next — no noise.
              </p>
            </div>

            <div className="flex flex-wrap gap-2 md:justify-end">
              <div className="inline-flex items-center gap-2 rounded-full bg-rose-500/10 border border-rose-500/50 px-3 py-1.5">
                <span className="text-xs">⚠</span>
                <span className="text-[11px] font-medium text-rose-50">
                  {alertSummary.highRiskVendors} high-risk vendors
                  {HIGH_RISK_THRESHOLD ? ` (≥${HIGH_RISK_THRESHOLD})` : ""}
                </span>
              </div>

              <div className="inline-flex items-center gap-2 rounded-full bg-rose-500/10 border border-rose-400/50 px-3 py-1.5">
                <span className="text-xs">📄</span>
                <span className="text-[11px] font-medium text-rose-50">
                  {alertSummary.vendorsMissingEvidence} with no evidence on file
                </span>
              </div>

              <div className="inline-flex items-center gap-2 rounded-full bg-sky-500/10 border border-sky-400/50 px-3 py-1.5">
                <span className="text-xs">📝</span>
                <span className="text-[11px] font-medium text-sky-50">
                  {alertSummary.vendorsWithoutAssessments} lacking assessments
                </span>
              </div>

              <div className="inline-flex items-center gap-2 rounded-full bg-violet-500/10 border border-violet-400/50 px-3 py-1.5">
                <span className="text-xs">⏱</span>
                <span className="text-[11px] font-medium text-violet-50">
                  {alertSummary.staleCriticalVendors} critical with stale
                  reviews
                </span>
              </div>
            </div>
          </div>

          {/* PER-VENDOR ALERT CHIPS */}
          {visibleAlerts.length > 0 && (
            <div className="mt-4 flex gap-2 overflow-x-auto pb-1">
              {visibleAlerts.map((alert, idx) => {
                const baseClasses =
                  "inline-flex min-w-[230px] items-start gap-2 rounded-2xl px-3 py-2 text-[11px] border transition whitespace-nowrap";
                let severityClasses =
                  "bg-amber-500/10 border-amber-500/40 text-amber-50";

                if (alert.severity === "high") {
                  severityClasses =
                    "bg-rose-500/12 border-rose-500/50 text-rose-50";
                } else if (alert.severity === "info") {
                  severityClasses =
                    "bg-sky-500/10 border-sky-500/40 text-sky-50";
                }

                const icon =
                  alert.severity === "high"
                    ? alert.code === "STALE_ASSESSMENTS"
                      ? "⏱"
                      : "⚠"
                    : alert.code === "STALE_ASSESSMENTS"
                    ? "⏱"
                    : "●";

                return (
                  <Link
                    key={`${alert.vendorId}-${alert.code}-${idx}`}
                    href={`/vendors/${alert.vendorId}`}
                    className={
                      baseClasses +
                      " " +
                      severityClasses +
                      " hover:-translate-y-0.5 hover:border-emerald-300/60 hover:shadow-md hover:shadow-emerald-500/20"
                    }
                  >
                    <span className="mt-[2px]">{icon}</span>
                    <span className="flex flex-col text-left">
                      <span className="font-semibold truncate">
                        {alert.vendorName}
                      </span>
                      <span className="opacity-90 truncate">
                        {alert.message}
                      </span>
                    </span>
                  </Link>
                );
              })}
            </div>
          )}

          {visibleAlerts.length === 0 && (
            <p className="mt-3 text-[11px] text-emerald-300">
              No active portfolio alerts based on current rules. This is what
              &ldquo;calm&rdquo; looks like.
            </p>
          )}
        </div>
      </section>

      {/* PORTFOLIO SUMMARY CARDS */}
      <section className="mt-12 grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="p-6 rounded-3xl bg-slate-950/70 border border-slate-800/80 shadow-md shadow-black/40">
          <p className="text-xs text-slate-400 flex items-center gap-2">
            <span className="text-lg">🧩</span>
            <span>Portfolio size</span>
          </p>
          <p className="mt-3 text-3xl font-semibold text-slate-50">
            {stats.vendorCount}
          </p>
          <p className="mt-2 text-xs text-slate-500">
            Vendors currently in scope for Truvern monitoring.
          </p>
        </div>

        <div className="p-6 rounded-3xl bg-slate-950/70 border border-slate-800/80 shadow-md shadow-black/40">
          <p className="text-xs text-slate-400 flex items-center gap-2">
            <span className="text-lg">🩺</span>
            <span>Overall health</span>
          </p>
          <p className="mt-3 text-3xl font-semibold text-emerald-300">
            {Number.isNaN(stats.avgHealth) ? "—" : stats.avgHealth}
          </p>
          <p className="mt-2 text-xs text-slate-500">
            Aggregated risk posture across your entire vendor set (0–100).
          </p>
        </div>

        <div className="p-6 rounded-3xl bg-slate-950/70 border border-slate-800/80 shadow-md shadow-black/40">
          <p className="text-xs text-slate-400 flex items-center gap-2">
            <span className="text-lg">📁</span>
            <span>Evidence on file</span>
          </p>
          <p className="mt-3 text-3xl font-semibold text-sky-300">
            {stats.evidenceItems}
          </p>
          <p className="mt-2 text-xs text-slate-500">
            Reports, policies, certificates, and other uploaded artifacts backing
            up your program.
          </p>
        </div>
      </section>

      {/* CIA ROLLUP */}
      <section className="mt-16">
        <div className="flex flex-col gap-2 md:flex-row md:items-end md:justify-between mb-4">
          <div>
            <p className="text-[11px] font-semibold uppercase tracking-[0.2em] text-slate-400">
              CIA posture
            </p>
            <h2 className="text-xl font-semibold text-slate-50">
              Confidentiality, Integrity &amp; Availability
            </h2>
            <p className="text-sm text-slate-400">
              A quick sense of how your vendor ecosystem is doing across the
              classic triad.
            </p>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div className="p-6 rounded-3xl bg-slate-950/70 border border-slate-800/80">
            <p className="text-xs text-slate-400 flex items-center gap-2">
              <span className="text-lg">🕵️‍♀️</span>
              <span>Confidentiality</span>
            </p>
            <p className="mt-3 text-3xl font-semibold text-slate-50">
              {stats.cia.confidentiality}
            </p>
            <p className="mt-2 text-xs text-slate-500">
              How well vendors protect sensitive data from unauthorized access.
            </p>
          </div>
          <div className="p-6 rounded-3xl bg-slate-950/70 border border-slate-800/80">
            <p className="text-xs text-slate-400 flex items-center gap-2">
              <span className="text-lg">✅</span>
              <span>Integrity</span>
            </p>
            <p className="mt-3 text-3xl font-semibold text-slate-50">
              {stats.cia.integrity}
            </p>
            <p className="mt-2 text-xs text-slate-500">
              Controls that preserve accuracy and trust in vendor data.
            </p>
          </div>
          <div className="p-6 rounded-3xl bg-slate-950/70 border border-slate-800/80">
            <p className="text-xs text-slate-400 flex items-center gap-2">
              <span className="text-lg">⏱</span>
              <span>Availability</span>
            </p>
            <p className="mt-3 text-3xl font-semibold text-slate-50">
              {stats.cia.availability}
            </p>
            <p className="mt-2 text-xs text-slate-500">
              Resilience and uptime expectations for critical vendor services.
            </p>
          </div>
        </div>
      </section>

      {/* TOP 10 RISKIEST VENDORS */}
      <section className="mt-18 md:mt-20">
        <div className="flex flex-col md:flex-row md:items-end md:justify-between gap-3 mb-4">
          <div>
            <p className="text-[11px] font-semibold uppercase tracking-[0.2em] text-slate-400">
              Focus list
            </p>
            <h2 className="text-xl font-semibold text-slate-50">
              Top 10 riskiest vendors
            </h2>
            <p className="text-sm text-slate-400">
              A short, calm list of where leadership attention pays off the
              fastest.
            </p>
          </div>
          <Link
            href="/vendors"
            className="text-xs font-medium text-emerald-300 hover:text-emerald-200"
          >
            View full vendor directory →
          </Link>
        </div>

        {topVendors.length === 0 ? (
          <p className="text-sm text-slate-500 border border-dashed border-slate-700 rounded-2xl px-4 py-6 bg-slate-950/60">
            No vendors found yet. As you add vendors, assessments, and evidence,
            Truvern will generate a focused list here automatically.
          </p>
        ) : (
          <div className="overflow-x-auto">
            <table className="min-w-full text-left border-separate border-spacing-y-2">
              <thead>
                <tr className="text-[11px] uppercase tracking-wide text-slate-400">
                  <th className="px-3 py-2">Vendor</th>
                  <th className="px-3 py-2">Risk score</th>
                  <th className="px-3 py-2">Assessments</th>
                  <th className="px-3 py-2">Evidence</th>
                </tr>
              </thead>
              <tbody>
                {topVendors.map((v) => {
                  const score = v.riskScore ?? undefined;
                  const riskBadge =
                    typeof score === "number"
                      ? score >= 85
                        ? "High"
                        : score >= 65
                        ? "Medium"
                        : "Low"
                      : undefined;
                  const riskClass =
                    riskBadge === "High"
                      ? "bg-rose-500/15 text-rose-200 border border-rose-400/40"
                      : riskBadge === "Medium"
                      ? "bg-amber-500/15 text-amber-100 border border-amber-400/40"
                      : "bg-emerald-500/15 text-emerald-100 border border-emerald-400/40";

                  return (
                    <tr
                      key={v.id}
                      className="bg-slate-950/70 hover:bg-slate-900/90 transition rounded-2xl"
                    >
                      <td className="px-3 py-3 text-sm font-medium text-slate-50">
                        <Link
                          href={`/vendors/${v.id}`}
                          className="hover:underline"
                        >
                          {v.name}
                        </Link>
                      </td>
                      <td className="px-3 py-3 text-sm text-slate-100">
                        <div className="flex items-center gap-2">
                          <span>{score ?? "—"}</span>
                          {riskBadge && (
                            <span
                              className={
                                "inline-flex items-center rounded-full px-2 py-0.5 text-[10px] font-semibold " +
                                riskClass
                              }
                            >
                              {riskBadge}
                            </span>
                          )}
                        </div>
                      </td>
                      <td className="px-3 py-3 text-sm text-slate-200">
                        {v._count.assessments}
                      </td>
                      <td className="px-3 py-3 text-sm text-slate-200">
                        {v._count.evidence}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </section>

      {/* MINI ACTIVITY FEED */}
      <section className="mt-12 pb-4">
        <div className="flex flex-col md:flex-row md:items-end md:justify-between gap-3 mb-3">
          <div>
            <p className="text-[11px] font-semibold uppercase tracking-[0.2em] text-slate-400">
              Recent activity
            </p>
            <h2 className="text-base font-semibold text-slate-50">
              What&apos;s been happening in your vendor space
            </h2>
            <p className="text-xs text-slate-400 max-w-md">
              A lightweight feed of new evidence and assessment updates —
              letting leaders feel the program is alive without diving into
              every screen.
            </p>
          </div>
        </div>

        {activityFeed.length === 0 ? (
          <p className="text-xs text-slate-500 border border-dashed border-slate-700 rounded-2xl px-4 py-4 bg-slate-950/60">
            No recent activity yet. As you add evidence and complete
            assessments, Truvern will surface a gentle stream of updates here.
          </p>
        ) : (
          <div className="rounded-2xl border border-slate-800/80 bg-slate-950/70 divide-y divide-slate-800/80">
            {activityFeed.map((item, idx) => (
              <Link
                key={`${item.vendorId}-${item.kind}-${idx}-${item.timestamp.toISOString()}`}
                href={`/vendors/${item.vendorId}`}
                className="flex items-center justify-between gap-3 px-4 py-3 hover:bg-slate-900/80 transition"
              >
                <div className="flex items-center gap-3">
                  <div className="flex h-8 w-8 items-center justify-center rounded-full bg-slate-900 border border-slate-700 text-xs">
                    {item.kind === "evidence" ? "📄" : "📝"}
                  </div>
                  <div className="flex flex-col">
                    <span className="text-xs font-semibold text-slate-100">
                      {item.vendorName}
                    </span>
                    <span className="text-[11px] text-slate-300 truncate">
                      {item.kind === "evidence"
                        ? `Added evidence: ${item.label}`
                        : item.label}
                    </span>
                  </div>
                </div>
                <div className="flex flex-col items-end gap-1">
                  <span className="inline-flex items-center rounded-full border border-slate-700 bg-slate-900/70 px-2 py-0.5 text-[10px] uppercase tracking-[0.16em] text-slate-400">
                    {item.accent}
                  </span>
                  <span className="text-[10px] text-slate-500">
                    {formatShortDate(item.timestamp)}
                  </span>
                </div>
              </Link>
            ))}
          </div>
        )}
      </section>
    </main>
  );
}
