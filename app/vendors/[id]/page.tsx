// app/vendors/[id]/page.tsx
import Link from "next/link";
import prisma from "@/lib/prisma";
import VendorEvidenceTimeline from "@/components/vendor-evidence-timeline";
import BoardPacketCTA from "@/components/board-packet-cta";

type ParamsPromise = Promise<{ id: string }>;
type SearchParamsPromise = Promise<{ as?: string }>;

type Props = {
  params: ParamsPromise;
  searchParams?: SearchParamsPromise;
};

function riskTone(score: number | null | undefined): string {
  if (score == null) return "bg-slate-800 text-slate-200 border-slate-700";
  if (score >= 85)
    return "bg-emerald-500/10 text-emerald-300 border-emerald-500/60";
  if (score >= 70) return "bg-cyan-500/10 text-cyan-300 border-cyan-500/60";
  if (score >= 50)
    return "bg-amber-500/10 text-amber-300 border-amber-500/60";
  return "bg-rose-500/10 text-rose-300 border-rose-500/60";
}

function riskLabel(score: number | null | undefined): string {
  if (score == null) return "Not scored";
  if (score >= 85) return `Low risk (${score})`;
  if (score >= 70) return `Moderate (${score})`;
  if (score >= 50) return `Elevated (${score})`;
  return `High risk (${score})`;
}

function chip(text: string | null | undefined) {
  if (!text) return null;
  return (
    <span className="inline-flex items-center rounded-full border border-slate-700 bg-slate-900/80 px-2 py-0.5 text-[10px] text-slate-300">
      {text}
    </span>
  );
}

function issueTone(count: number) {
  if (count >= 10) return "bg-rose-500/10 text-rose-200 border-rose-500/30";
  if (count >= 4) return "bg-amber-500/10 text-amber-200 border-amber-500/30";
  if (count >= 1) return "bg-sky-500/10 text-sky-200 border-sky-500/30";
  return "bg-slate-900/70 text-slate-300 border-slate-700";
}

export default async function VendorDetailPage({ params, searchParams }: Props) {
  const { id } = await params;
  const sp = searchParams ? await searchParams : {};
  const asVendor = sp?.as === "vendor";

  const vendorId = Number(id);

  if (!vendorId || Number.isNaN(vendorId)) {
    return (
      <main className="max-w-3xl mx-auto px-4 py-12">
        <p className="text-sm text-rose-300">
          Invalid vendor id in URL. Please return to your vendor list.
        </p>
      </main>
    );
  }

  const vendor = await prisma.vendor.findUnique({
    where: { id: vendorId },
    include: {
      organization: true,
      trustProfile: true,
      evidence: true,
      issues: true,
      assessments: {
        orderBy: { createdAt: "desc" },
        include: { template: true },
      },
    },
  });

  if (!vendor) {
    return (
      <main className="max-w-3xl mx-auto px-4 py-12">
        <p className="text-sm text-rose-300">
          Vendor not found. Please return to your vendor list.
        </p>
      </main>
    );
  }

  const assessmentCount = vendor.assessments.length;
  const evidenceCount = vendor.evidence.length;

  // ✅ FIX: treat ACCEPTED_RISK as NOT open
  // Only "OPEN" + "IN_REVIEW" count as open issues on the workspace.
  const OPEN_STATUSES = new Set(["OPEN", "IN_REVIEW"]);

  const openIssues = vendor.issues.filter((i) =>
    OPEN_STATUSES.has(String(i.status))
  ).length;

  const criticalOpen = vendor.issues.filter(
    (i) =>
      OPEN_STATUSES.has(String(i.status)) &&
      String(i.severity) === "CRITICAL"
  ).length;

  // Optional: show accepted risks separately (useful for audit visibility)
  const acceptedRiskCount = vendor.issues.filter(
    (i) => String(i.status) === "ACCEPTED_RISK"
  ).length;

  // ✅ Trust-profile-safe summary (Vendor model does NOT have `summary` in your schema)
  const summary = vendor.trustProfile?.summary ?? null;

  return (
    <main className="relative max-w-6xl mx-auto px-4 lg:px-6 py-12 lg:py-16">
      <section className="mb-5 rounded-3xl border border-slate-800 bg-slate-950/80 px-4 py-4 shadow-lg shadow-black/40">
        <div className="flex flex-col gap-4 md:flex-row md:items-start md:justify-between">
          <div className="space-y-2">
            <h1 className="text-2xl lg:text-3xl font-semibold text-slate-50">
              {vendor.name}
            </h1>

            <div className="flex flex-wrap gap-2">
              {chip(vendor.category)}
              {chip(vendor.tier ? `Tier: ${vendor.tier}` : null)}
              {chip(
                vendor.criticality ? `Criticality: ${vendor.criticality}` : null
              )}
              {!asVendor &&
                chip(
                  vendor.organization?.name
                    ? `Org: ${vendor.organization.name}`
                    : null
                )}
            </div>

            {asVendor && (
              <div className="mt-3 rounded-2xl border border-emerald-500/20 bg-emerald-500/5 px-4 py-3 text-sm text-emerald-100">
                You’re viewing the{" "}
                <span className="font-semibold">Vendor Portal</span> safe version
                of this profile (internal-only widgets hidden).
              </div>
            )}
          </div>

          <div className="flex flex-wrap items-center justify-end gap-2">
            {!asVendor ? (
              <Link
                href={`/vendors/${vendor.id}?as=vendor`}
                className="inline-flex items-center gap-2 rounded-full border border-white/10 bg-white/5 px-3 py-1.5 text-[11px] font-semibold text-slate-100 hover:bg-white/10"
              >
                View as Vendor
              </Link>
            ) : (
              <Link
                href={`/vendors/${vendor.id}`}
                className="inline-flex items-center gap-2 rounded-full border border-emerald-500/25 bg-emerald-500/10 px-3 py-1.5 text-[11px] font-semibold text-emerald-100 hover:bg-emerald-500/15"
              >
                Back to Internal View
              </Link>
            )}

            {!asVendor && (
              <>
                <BoardPacketCTA variant="ghost" label="Board Packet" />

                <Link
                  href={`/vendors/${vendor.id}/findings`}
                  className="inline-flex items-center gap-2 rounded-full border border-amber-400/50 bg-amber-500/10 px-3 py-1.5 text-[11px] font-semibold text-amber-200 hover:bg-amber-500/15"
                >
                  Findings ↗
                </Link>

                <Link
                  href={`/vendors/${vendor.id}/evidence-requests/new`}
                  className="inline-flex items-center gap-2 rounded-full border border-sky-400/40 bg-sky-500/10 px-3 py-1.5 text-[11px] font-semibold text-sky-200 hover:bg-sky-500/15"
                >
                  Request evidence ↗
                </Link>

                <Link
                  href={`/assessment/new/${vendor.id}`}
                  className="inline-flex items-center gap-2 rounded-full bg-emerald-500 px-4 py-2 text-[12px] font-semibold text-slate-950 shadow-md hover:bg-emerald-400"
                >
                  Start assessment ↗
                </Link>
              </>
            )}

            {asVendor && (
              <Link
                href="/vendor-portal"
                className="inline-flex items-center gap-2 rounded-full bg-emerald-500 px-4 py-2 text-[12px] font-semibold text-slate-950 shadow-md hover:bg-emerald-400"
              >
                Go to Vendor Portal ↗
              </Link>
            )}
          </div>
        </div>

        <div className="mt-4 flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
          <div className="text-sm text-slate-200/80 max-w-3xl">
            {summary ? (
              summary
            ) : (
              <span className="text-slate-200/60">
                No vendor summary yet. Add a short description to improve the
                trust profile.
              </span>
            )}
          </div>

          <div className="flex flex-wrap items-center gap-2">
            <span
              className={`inline-flex items-center rounded-full border px-3 py-1 text-[11px] font-semibold ${riskTone(
                vendor.riskScore
              )}`}
              title="Vendor health / risk"
            >
              {riskLabel(vendor.riskScore)}
            </span>

            {!asVendor && (
              <>
                <span
                  className={`inline-flex items-center rounded-full border px-3 py-1 text-[11px] font-semibold ${issueTone(
                    openIssues
                  )}`}
                  title="Open issues (excludes accepted risk)"
                >
                  Issues: {openIssues}
                  {criticalOpen > 0 ? ` (Critical: ${criticalOpen})` : ""}
                </span>

                {acceptedRiskCount > 0 ? (
                  <span
                    className="inline-flex items-center rounded-full border border-white/10 bg-white/5 px-3 py-1 text-[11px] font-semibold text-slate-200/80"
                    title="Accepted risks (tracked, not blocking)"
                  >
                    Accepted risk: {acceptedRiskCount}
                  </span>
                ) : null}
              </>
            )}
          </div>
        </div>
      </section>

      <div className="grid grid-cols-1 lg:grid-cols-[minmax(0,1.4fr)_minmax(0,1fr)] gap-5">
        <div className="space-y-5">
          <section className="rounded-3xl border border-slate-800 bg-slate-950/80 px-4 py-4">
            <VendorEvidenceTimeline vendorId={vendor.id} vendorName={vendor.name} />
          </section>

          {!asVendor && (
            <section className="rounded-3xl border border-slate-800 bg-slate-950/80 px-4 py-4">
              <div className="flex items-center justify-between">
                <p className="text-[11px] font-semibold uppercase tracking-[0.18em] text-slate-400">
                  Recent assessments
                </p>
                <Link
                  href="/assessment"
                  className="text-xs text-slate-200/60 hover:text-slate-100"
                >
                  View all ↗
                </Link>
              </div>

              {vendor.assessments.length === 0 ? (
                <p className="mt-3 text-sm text-slate-200/60">No assessments yet.</p>
              ) : (
                <div className="mt-3 divide-y divide-white/5 overflow-hidden rounded-2xl border border-white/10">
                  {vendor.assessments.slice(0, 6).map((a) => (
                    <Link
                      key={a.id}
                      href={`/assessment/runs/${a.id}`}
                      className="block px-4 py-3 hover:bg-white/5"
                    >
                      <div className="flex items-center justify-between gap-3">
                        <div className="text-sm font-medium text-slate-50">
                          {a.title ?? `Assessment #${a.id}`}
                        </div>
                        <div className="text-xs text-slate-200/60">
                          {new Date(a.createdAt as any).toLocaleDateString()}
                        </div>
                      </div>
                      <div className="mt-1 text-xs text-slate-200/70">
                        Status: {a.status ?? "—"}
                        {a.template?.name ? ` • Template: ${a.template.name}` : ""}
                      </div>
                    </Link>
                  ))}
                </div>
              )}
            </section>
          )}
        </div>

        <aside className="space-y-5">
          <section className="rounded-3xl border border-slate-800 bg-slate-950/80 px-4 py-4">
            <p className="text-[11px] font-semibold uppercase tracking-[0.18em] text-slate-400 mb-2">
              At a glance
            </p>

            <div className="space-y-2 text-[12px] text-slate-300">
              <div className="flex justify-between">
                <span>Risk score</span>
                <span className="font-semibold">{vendor.riskScore ?? "Not scored"}</span>
              </div>
              <div className="flex justify-between">
                <span>Assessments</span>
                <span>{assessmentCount}</span>
              </div>
              <div className="flex justify-between">
                <span>Evidence</span>
                <span>{evidenceCount}</span>
              </div>

              {!asVendor ? (
                <div className="flex justify-between">
                  <span>Open issues</span>
                  <span className="text-amber-300 font-semibold">{openIssues}</span>
                </div>
              ) : (
                <div className="flex justify-between">
                  <span>Trust status</span>
                  <span className="font-semibold text-emerald-200">Verified</span>
                </div>
              )}
            </div>

            {!asVendor && (
              <div className="mt-4">
                <BoardPacketCTA variant="ghost" label="View in Board Packet" />
              </div>
            )}

            {asVendor && (
              <div className="mt-4">
                <Link
                  href="/vendor-portal"
                  className="inline-flex w-full items-center justify-center rounded-xl border border-emerald-500/25 bg-emerald-500/10 px-4 py-2 text-sm font-semibold text-emerald-100 hover:bg-emerald-500/15"
                >
                  Open Vendor Portal ↗
                </Link>
              </div>
            )}
          </section>

          {/* ✅ Only show “Critical attention” when there are OPEN/IN_REVIEW critical issues */}
          {!asVendor && criticalOpen > 0 && (
            <section className="rounded-3xl border border-rose-500/25 bg-rose-500/10 px-4 py-4">
              <p className="text-[11px] font-semibold uppercase tracking-[0.18em] text-rose-200">
                Critical attention
              </p>
              <p className="mt-2 text-sm text-rose-100/90">
                {criticalOpen} critical issue{criticalOpen === 1 ? "" : "s"} open.
                Prioritize remediation and evidence updates.
              </p>
              <div className="mt-3">
                <Link
                  href={`/vendors/${vendor.id}/findings`}
                  className="inline-flex items-center rounded-full border border-rose-300/30 bg-rose-500/10 px-3 py-1.5 text-xs font-semibold text-rose-100 hover:bg-rose-500/15"
                >
                  Review Findings ↗
                </Link>
              </div>
            </section>
          )}
        </aside>
      </div>
    </main>
  );
}
