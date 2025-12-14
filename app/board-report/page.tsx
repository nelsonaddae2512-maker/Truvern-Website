// app/board-report/page.tsx
import prisma from "@/lib/prisma";
import Link from "next/link";
import BoardReportPrintButton from "@/components/board-report-print-button";
import BoardPacketCTA from "@/components/board-packet-cta";

export const dynamic = "force-dynamic";

function formatDate(value: string | Date | null | undefined) {
  if (!value) return "—";
  const d = typeof value === "string" ? new Date(value) : value;
  if (Number.isNaN(d.getTime())) return "—";
  return d.toLocaleDateString(undefined, {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}

function riskLabel(score: number | null | undefined) {
  if (score == null) {
    return {
      label: "Unknown",
      className:
        "inline-flex items-center rounded-full border border-slate-700 bg-slate-950/80 px-2 py-[3px] text-[11px] text-slate-300",
    };
  }

  if (score >= 80) {
    return {
      label: "Low",
      className:
        "inline-flex items-center rounded-full border border-emerald-500/40 bg-emerald-500/10 px-2 py-[3px] text-[11px] text-emerald-300",
    };
  }

  if (score >= 60) {
    return {
      label: "Medium",
      className:
        "inline-flex items-center rounded-full border border-amber-500/40 bg-amber-500/10 px-2 py-[3px] text-[11px] text-amber-300",
    };
  }

  return {
    label: "High",
    className:
      "inline-flex items-center rounded-full border border-rose-500/50 bg-rose-500/10 px-2 py-[3px] text-[11px] text-rose-300",
  };
}

function averageOf(values: (number | null | undefined)[]): number | null {
  const nums = values.filter(
    (v) => typeof v === "number" && !Number.isNaN(Number(v))
  ) as number[];
  if (nums.length === 0) return null;
  const sum = nums.reduce((acc, n) => acc + n, 0);
  return Math.round(sum / nums.length);
}

export default async function BoardReportPage() {
  const [vendorAgg, vendorsRaw, assessmentsCount, evidenceCount] =
    await Promise.all([
      prisma.vendor.aggregate({
        _avg: { riskScore: true },
        _count: true,
      }),
      prisma.vendor.findMany({
        orderBy: { riskScore: "asc" }, // high risk first
        take: 25,
        include: {
          _count: {
            select: {
              assessments: true,
              evidence: true,
            },
          },
          evidence: {
            orderBy: { uploadedAt: "desc" },
            take: 1,
            select: {
              uploadedAt: true,
            },
          },
          assessments: {
            select: {
              score: true,
              confidentialityScore: true,
              integrityScore: true,
              availabilityScore: true,
            },
          },
        },
      }),
      prisma.assessment.count(),
      prisma.evidence.count(),
    ]);

  const vendors = vendorsRaw as any[];
  const vendorCount = vendorAgg._count;
  const avgHealth = Math.round(vendorAgg._avg.riskScore ?? 0);

  const highRiskCount = vendors.filter((v) => {
    const score: number | null = v.riskScore ?? null;
    return score != null && score < 60;
  }).length;

  const mediumRiskCount = vendors.filter((v) => {
    const score: number | null = v.riskScore ?? null;
    return score != null && score >= 60 && score < 80;
  }).length;

  const lowRiskCount = vendors.filter((v) => {
    const score: number | null = v.riskScore ?? null;
    return score != null && score >= 80;
  }).length;

  return (
    <main className="min-h-screen bg-slate-950 text-slate-50 print:bg-white print:text-slate-900">
      <div className="mx-auto flex max-w-6xl flex-col gap-8 px-4 pb-24 pt-10 lg:pt-12">
        {/* Header */}
        <header className="space-y-3">
          <p className="text-xs font-semibold tracking-[0.22em] text-emerald-300">
            EXECUTIVE OVERVIEW
          </p>

          <div className="flex flex-col justify-between gap-3 md:flex-row md:items-end">
            <div>
              <div className="flex flex-wrap items-center gap-2">
                <h1 className="text-3xl font-semibold tracking-tight md:text-4xl">
                  Board Report
                </h1>

                {/* ✅ New: Board Packet CTA (hidden in print) */}
                <div className="print:hidden">
                  <BoardPacketCTA
                    variant="ghost"
                    label="Open Board Packet"
                    className="ml-0 md:ml-2"
                  />
                </div>
              </div>

              <p className="mt-2 max-w-2xl text-sm text-slate-300">
                High-level snapshot of third-party risk posture in Truvern. Use
                this view when briefing the board, execs, or audit committees on
                vendor health, assessments, and evidence coverage.
              </p>
            </div>

            <div className="flex flex-col items-start gap-1 text-xs text-slate-400 md:items-end md:text-right">
              <span>
                Vendors in scope:{" "}
                <span className="font-semibold text-slate-50">{vendorCount}</span>
              </span>
              <span>
                Assessments in Truvern:{" "}
                <span className="font-semibold text-slate-50">
                  {assessmentsCount}
                </span>
              </span>
              <span>
                Evidence items:{" "}
                <span className="font-semibold text-slate-50">{evidenceCount}</span>
              </span>
            </div>
          </div>
        </header>

        {/* Print-only heading for exported/PDF view */}
        <section className="hidden print:block -mt-2">
          <h1 className="text-2xl font-semibold text-slate-900">
            Truvern Board Risk Snapshot
          </h1>
          <p className="text-sm text-slate-700">
            Generated from Truvern – Vendor risk you can actually trust.
          </p>
        </section>

        {/* Summary tiles */}
        <section className="grid gap-4 md:grid-cols-4">
          <div className="rounded-2xl border border-slate-800 bg-slate-900/60 p-4">
            <p className="text-[11px] uppercase tracking-[0.18em] text-slate-400">
              Vendors in Truvern
            </p>
            <p className="mt-2 text-2xl font-semibold text-slate-50">
              {vendorCount}
            </p>
            <p className="mt-1 text-xs text-slate-400">
              Organisations actively tracked in the Truvern TPRM Trust Network.
            </p>
          </div>

          <div className="rounded-2xl border border-slate-800 bg-slate-900/60 p-4">
            <p className="text-[11px] uppercase tracking-[0.18em] text-slate-400">
              Avg. health score
            </p>
            <p className="mt-2 text-2xl font-semibold text-emerald-300">
              {avgHealth}
              <span className="ml-1 text-sm text-slate-500">/100</span>
            </p>
            <p className="mt-1 text-xs text-slate-400">
              Simple average of vendor risk scores across the portfolio.
            </p>
          </div>

          <div className="rounded-2xl border border-slate-800 bg-slate-900/60 p-4">
            <p className="text-[11px] uppercase tracking-[0.18em] text-slate-400">
              High-risk vendors
            </p>
            <p className="mt-2 text-2xl font-semibold text-rose-300">
              {highRiskCount}
            </p>
            <p className="mt-1 text-xs text-slate-400">
              Vendors with a health score below 60/100 that require focused
              oversight and remediation.
            </p>
          </div>

          <div className="rounded-2xl border border-slate-800 bg-slate-900/60 p-4">
            <p className="text-[11px] uppercase tracking-[0.18em] text-slate-400">
              Assessments &amp; evidence
            </p>
            <p className="mt-2 text-lg font-semibold text-slate-50">
              {assessmentsCount} assessments
            </p>
            <p className="text-xs text-slate-300">
              {evidenceCount} evidence item{evidenceCount === 1 ? "" : "s"}
            </p>
            <p className="mt-1 text-xs text-slate-400">
              Questionnaires and supporting documentation maintained in Truvern.
            </p>
          </div>
        </section>

        {/* Risk distribution bar */}
        <section className="rounded-2xl border border-slate-800 bg-slate-900/60 p-5 text-xs text-slate-200">
          <div className="flex items-center justify-between gap-2">
            <h2 className="text-sm font-semibold tracking-tight text-slate-50">
              Risk distribution
            </h2>
            <span className="text-[11px] text-slate-500">
              High risk &lt; 60 · Medium 60–79 · Low ≥ 80
            </span>
          </div>

          <div className="mt-4 flex flex-col gap-3 md:flex-row md:items-center md:gap-6">
            <div className="flex-1 rounded-full bg-slate-900/80 p-1">
              <div className="flex h-3 overflow-hidden rounded-full">
                <div
                  style={{
                    width:
                      vendorCount === 0
                        ? "0%"
                        : `${(highRiskCount / vendorCount) * 100}%`,
                  }}
                  className="bg-rose-500/70"
                />
                <div
                  style={{
                    width:
                      vendorCount === 0
                        ? "0%"
                        : `${(mediumRiskCount / vendorCount) * 100}%`,
                  }}
                  className="bg-amber-500/70"
                />
                <div
                  style={{
                    width:
                      vendorCount === 0
                        ? "0%"
                        : `${(lowRiskCount / vendorCount) * 100}%`,
                  }}
                  className="bg-emerald-500/70"
                />
              </div>
            </div>
            <div className="flex flex-wrap gap-3 text-[11px] text-slate-400">
              <span className="inline-flex items-center gap-1">
                <span className="h-2 w-2 rounded-full bg-rose-500/80" /> High:{" "}
                <span className="font-semibold text-slate-100">
                  {highRiskCount}
                </span>
              </span>
              <span className="inline-flex items-center gap-1">
                <span className="h-2 w-2 rounded-full bg-amber-500/80" /> Medium:{" "}
                <span className="font-semibold text-slate-100">
                  {mediumRiskCount}
                </span>
              </span>
              <span className="inline-flex items-center gap-1">
                <span className="h-2 w-2 rounded-full bg-emerald-500/80" /> Low:{" "}
                <span className="font-semibold text-slate-100">{lowRiskCount}</span>
              </span>
            </div>
          </div>
        </section>

        {/* Vendor table for board */}
        <section className="rounded-2xl border border-slate-800 bg-slate-900/60 p-5">
          <div className="mb-3 flex items-center justify-between gap-2">
            <div>
              <h2 className="text-sm font-semibold tracking-tight text-slate-50">
                Vendor portfolio for board review
              </h2>
              <p className="text-[11px] text-slate-500">
                Top {vendors.length} vendors by risk score · high risk first.
              </p>
            </div>

            {/* Actions: Board Packet + CSV export + Print, hidden in print view */}
            <div className="flex items-center gap-2 print:hidden">
              <BoardPacketCTA variant="ghost" label="Board Packet" />
              <Link
                href="/api/board-report"
                className="rounded-full border border-slate-700 bg-slate-950/70 px-3 py-1.5 text-[11px] font-medium text-slate-100 hover:border-emerald-400/70 hover:bg-slate-900"
              >
                Export CSV
              </Link>
              <BoardReportPrintButton />
            </div>
          </div>

          {vendors.length === 0 ? (
            <p className="text-xs text-slate-400">
              No vendors found. Once you onboard vendors into Truvern, this
              section will summarise key risk metrics for the board.
            </p>
          ) : (
            <div className="divide-y divide-slate-800 text-xs">
              {/* Header row */}
              <div className="grid grid-cols-[minmax(0,2.2fr)_minmax(0,0.9fr)_minmax(0,0.9fr)_minmax(0,0.9fr)_minmax(0,1.1fr)_auto] gap-3 pb-2 text-[11px] text-slate-500">
                <span>Vendor</span>
                <span>Health</span>
                <span>Risk band</span>
                <span>Assessments</span>
                <span>Evidence snapshot</span>
                <span className="text-right">Workspace</span>
              </div>

              {/* Rows */}
              {vendors.map((v) => {
                const score: number | null = v.riskScore ?? null;
                const label = riskLabel(score);
                const lastEvidenceDate = v.evidence[0]?.uploadedAt ?? null;

                const assessmentsForVendor = (v.assessments ?? []) as any[];

                const avgCIAOverall = averageOf(
                  assessmentsForVendor.map((a) => a.score as number | null)
                );
                const avgC = averageOf(
                  assessmentsForVendor.map(
                    (a) => a.confidentialityScore as number | null
                  )
                );
                const avgI = averageOf(
                  assessmentsForVendor.map(
                    (a) => a.integrityScore as number | null
                  )
                );
                const avgA = averageOf(
                  assessmentsForVendor.map(
                    (a) => a.availabilityScore as number | null
                  )
                );

                return (
                  <div
                    key={v.id}
                    className="grid grid-cols-[minmax(0,2.2fr)_minmax(0,0.9fr)_minmax(0,0.9fr)_minmax(0,0.9fr)_minmax(0,1.1fr)_auto] gap-3 py-2.5 text-xs text-slate-200"
                  >
                    {/* Vendor */}
                    <div className="flex flex-col">
                      <Link
                        href={`/vendors/${v.id}?view=workspace`}
                        className="text-[13px] font-medium text-slate-50 hover:text-emerald-300"
                      >
                        {v.name}
                      </Link>
                      <span className="mt-0.5 text-[11px] text-slate-500">
                        Added {formatDate(v.createdAt)}
                      </span>
                    </div>

                    {/* Health score */}
                    <div className="flex flex-col justify-center gap-0.5">
                      <span className="text-sm font-semibold text-emerald-300">
                        {score ?? 0}
                        <span className="ml-1 text-[11px] text-slate-500">
                          /100
                        </span>
                      </span>
                      <span className="text-[10px] text-slate-500">
                        {avgCIAOverall != null
                          ? `Avg assessment score ${avgCIAOverall}/100`
                          : "No scored assessments"}
                      </span>
                    </div>

                    {/* Risk band */}
                    <div className="flex items-center">
                      <span className={label.className}>{label.label}</span>
                    </div>

                    {/* Assessments + CIA */}
                    <div className="flex flex-col justify-center gap-0.5">
                      <span className="text-[11px] text-slate-200">
                        {v._count.assessments} assessment
                        {v._count.assessments === 1 ? "" : "s"}
                      </span>
                      <span className="text-[10px] text-slate-500">
                        {v._count.evidence} evidence item
                        {v._count.evidence === 1 ? "" : "s"}
                      </span>
                      <span className="text-[10px] text-slate-500">
                        CIA: {avgC != null ? `C ${avgC}` : "C —"} ·{" "}
                        {avgI != null ? `I ${avgI}` : "I —"} ·{" "}
                        {avgA != null ? `A ${avgA}` : "A —"}
                      </span>
                    </div>

                    {/* Evidence snapshot */}
                    <div className="flex flex-col justify-center">
                      <span className="text-[11px] text-slate-200">
                        {lastEvidenceDate ? formatDate(lastEvidenceDate) : "—"}
                      </span>
                      <span className="text-[10px] text-slate-500">
                        Date of last evidence upload
                      </span>
                    </div>

                    {/* Actions */}
                    <div className="flex items-center justify-end">
                      <Link
                        href={`/vendors/${v.id}?view=workspace`}
                        className="rounded-full border border-slate-700 bg-slate-950/70 px-3 py-1.5 text-[11px] font-medium text-slate-100 hover:border-emerald-400/70 hover:bg-slate-900"
                      >
                        Open workspace
                      </Link>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </section>

        {/* Footer hint */}
        <section className="mt-2 text-[11px] text-slate-500">
          <p>
            This view is optimised for board and executive discussions. For
            detailed remediation plans and question-level answers, use the{" "}
            <Link href="/vendors" className="text-emerald-300 hover:text-emerald-200">
              vendor workspace
            </Link>{" "}
            and{" "}
            <Link href="/assessment" className="text-emerald-300 hover:text-emerald-200">
              assessment builder
            </Link>
            .
          </p>
        </section>
      </div>
    </main>
  );
}
