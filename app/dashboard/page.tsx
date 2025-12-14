// app/dashboard/page.tsx
import prisma from "@/lib/prisma";
import Link from "next/link";

export const dynamic = "force-dynamic";

function formatDate(value: string | Date) {
  const d = typeof value === "string" ? new Date(value) : value;
  return d.toLocaleDateString(undefined, {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}

type ActivityItem =
  | {
      type: "EVIDENCE";
      at: Date;
      vendorId: number | null;
      vendorName: string;
      title: string;
      kind?: string | null;
    }
  | {
      type: "ASSESSMENT";
      at: Date;
      vendorId: number | null;
      vendorName: string;
      title: string;
    };

export default async function VendorWorkspaceDashboard() {
  const [
    vendorCount,
    evidenceCount,
    avgHealthAgg,
    recentVendors,
    recentEvidence,
    recentAssessments,
  ] = await Promise.all([
    prisma.vendor.count(),
    prisma.evidence.count(),
    prisma.vendor.aggregate({
      _avg: { riskScore: true },
    }),
    prisma.vendor.findMany({
      orderBy: { createdAt: "desc" },
      take: 5,
      include: {
        _count: {
          select: {
            assessments: true,
            evidence: true,
          },
        },
      },
    }),
    prisma.evidence.findMany({
      orderBy: { uploadedAt: "desc" },
      take: 10,
      include: {
        vendor: {
          select: {
            id: true,
            name: true,
          },
        },
      },
    }),
    prisma.assessment.findMany({
      orderBy: { createdAt: "desc" },
      take: 10,
      include: {
        vendor: {
          select: {
            id: true,
            name: true,
          },
        },
      },
    }),
  ]);

  const avgHealth = Math.round(avgHealthAgg._avg.riskScore ?? 0);

  // Build unified activity list
  const evidenceActivities: ActivityItem[] = recentEvidence.map((e) => ({
    type: "EVIDENCE",
    at: e.uploadedAt as Date,
    vendorId: e.vendor?.id ?? null,
    vendorName: e.vendor?.name ?? "Unknown vendor",
    title: e.title,
    kind: e.kind,
  }));

  const assessmentActivities: ActivityItem[] = recentAssessments.map((a) => ({
    type: "ASSESSMENT",
    at: a.createdAt as Date,
    vendorId: (a as any).vendor?.id ?? null,
    vendorName: (a as any).vendor?.name ?? "Unknown vendor",
    title: (a as any).title ?? `Assessment #${(a as any).id}`,
  }));

  const activities = [...evidenceActivities, ...assessmentActivities].sort(
    (a, b) => b.at.getTime() - a.at.getTime()
  );

  const activityItems = activities.slice(0, 10);

  return (
    <main className="min-h-screen bg-slate-950 text-slate-50">
      <div className="mx-auto flex max-w-6xl flex-col gap-8 px-4 pb-24 pt-10">
        {/* Header */}
        <header className="space-y-3">
          <div className="flex items-center justify-between gap-3">
            <div>
              <p className="text-xs font-semibold tracking-[0.22em] text-emerald-300">
                VENDOR WORKSPACE
              </p>
              <h1 className="mt-2 text-3xl font-semibold tracking-tight md:text-4xl">
                Your Truvern vendor space
              </h1>
            </div>
            <div className="hidden rounded-full border border-emerald-400/40 bg-emerald-500/10 px-3 py-1 text-[11px] font-medium text-emerald-200 md:inline-flex md:items-center">
              <span className="mr-1 inline-flex h-1.5 w-1.5 rounded-full bg-emerald-400" />
              Truvern Integrity · Master seal verified
            </div>
          </div>
          <p className="max-w-2xl text-sm text-slate-300">
            This is your private command centre for the Truvern TPRM Trust
            Network. Monitor vendor health, review new evidence, and jump into
            board-ready reporting — all from one place.
          </p>
        </header>

        {/* Top stats + quick actions */}
        <section className="grid gap-4 md:grid-cols-[minmax(0,1.6fr)_minmax(0,1.2fr)]">
          {/* Stats cards */}
          <div className="grid gap-4 sm:grid-cols-3">
            <div className="rounded-2xl border border-slate-800 bg-slate-900/60 p-4">
              <p className="text-[11px] uppercase tracking-[0.18em] text-slate-400">
                Vendors live
              </p>
              <p className="mt-2 text-2xl font-semibold text-slate-50">
                {vendorCount}
              </p>
              <p className="mt-1 text-xs text-slate-400">
                Active vendors in your Truvern network.
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
                Simple average of risk scores across all vendors.
              </p>
            </div>

            <div className="rounded-2xl border border-slate-800 bg-slate-900/60 p-4">
              <p className="text-[11px] uppercase tracking-[0.18em] text-slate-400">
                Evidence items
              </p>
              <p className="mt-2 text-2xl font-semibold text-slate-50">
                {evidenceCount}
              </p>
              <p className="mt-1 text-xs text-slate-400">
                Reports, policies, and certifications tracked in Truvern.
              </p>
            </div>
          </div>

          {/* Quick actions */}
          <div className="rounded-2xl border border-slate-800 bg-slate-900/60 p-4 text-sm text-slate-200">
            <p className="text-xs font-semibold uppercase tracking-[0.18em] text-slate-400">
              Quick actions
            </p>
            <p className="mt-2 text-xs text-slate-400">
              Common entry points for your day-to-day work in Truvern.
            </p>
            <div className="mt-3 grid gap-2 sm:grid-cols-2">
              <Link
                href="/vendors"
                className="rounded-xl border border-slate-800 bg-slate-950/60 px-3 py-2.5 text-xs font-medium text-slate-100 transition hover:border-emerald-400/70 hover:bg-slate-900"
              >
                View all vendors
              </Link>
              <Link
                href="/trust-network"
                className="rounded-xl border border-slate-800 bg-slate-950/60 px-3 py-2.5 text-xs font-medium text-slate-100 transition hover:border-emerald-400/70 hover:bg-slate-900"
              >
                Open Trust Network
              </Link>
              <Link
                href="/board-report"
                className="rounded-xl border border-slate-800 bg-slate-950/60 px-3 py-2.5 text-xs font-medium text-slate-100 transition hover:border-emerald-400/70 hover:bg-slate-900"
              >
                Board report view
              </Link>
              <Link
                href="/pricing"
                className="rounded-xl border border-slate-800 bg-slate-950/60 px-3 py-2.5 text-xs font-medium text-slate-100 transition hover:border-emerald-400/70 hover:bg-slate-900"
              >
                Manage plan & limits
              </Link>
              <Link
                href="/assessment"
                className="rounded-xl border border-slate-800 bg-slate-950/60 px-3 py-2.5 text-xs font-medium text-slate-100 transition hover:border-emerald-400/70 hover:bg-slate-900"
              >
                Manage assessments
              </Link>
            </div>
          </div>
        </section>

        {/* Lower grid: recent vendors + activity feed */}
        <section className="grid gap-6 md:grid-cols-[minmax(0,1.5fr)_minmax(0,1.3fr)]">
          {/* Recent vendors */}
          <div className="rounded-2xl border border-slate-800 bg-slate-900/60 p-5">
            <div className="flex items-center justify-between gap-2">
              <h2 className="text-sm font-semibold tracking-tight text-slate-50">
                Recently added vendors
              </h2>
              <Link
                href="/vendors"
                className="text-[11px] font-medium text-emerald-300 hover:text-emerald-200"
              >
                View all
              </Link>
            </div>
            <p className="mt-1 text-xs text-slate-400">
              The latest vendors added to your Truvern network.
            </p>

            <div className="mt-4 space-y-2">
              {recentVendors.length === 0 && (
                <p className="text-xs text-slate-400">
                  No vendors yet. Start by adding your first critical supplier.
                </p>
              )}

              {recentVendors.map((v) => (
                <Link
                  key={v.id}
                  href={`/vendors/${v.id}?view=workspace`}
                  className="flex items-center justify-between gap-3 rounded-xl border border-slate-800 bg-slate-950/60 px-3 py-2.5 text-xs text-slate-200 transition hover:border-emerald-400/70 hover:bg-slate-900"
                >
                  <div>
                    <p className="font-medium text-slate-50">{v.name}</p>
                    <p className="mt-0.5 text-[11px] text-slate-400">
                      {v._count.assessments} assessment
                      {v._count.assessments === 1 ? "" : "s"} ·{" "}
                      {v._count.evidence} evidence item
                      {v._count.evidence === 1 ? "" : "s"}
                    </p>
                  </div>
                  <p className="text-[11px] text-slate-500">
                    Added {formatDate(v.createdAt)}
                  </p>
                </Link>
              ))}
            </div>
          </div>

          {/* Activity feed */}
          <div className="rounded-2xl border border-slate-800 bg-slate-900/60 p-5">
            <div className="flex items-center justify-between gap-2">
              <h2 className="text-sm font-semibold tracking-tight text-slate-50">
                Activity feed
              </h2>
              <span className="text-[10px] uppercase tracking-[0.18em] text-slate-500">
                Last {activityItems.length} updates
              </span>
            </div>
            <p className="mt-1 text-xs text-slate-400">
              Evidence uploads and assessment activity across your vendors.
            </p>

            <div className="mt-4 space-y-2">
              {activityItems.length === 0 && (
                <p className="text-xs text-slate-400">
                  No recent activity yet. Upload evidence or create an
                  assessment to see it appear here.
                </p>
              )}

              {activityItems.map((item, idx) => {
                const href =
                  item.vendorId != null
                    ? `/vendors/${item.vendorId}?view=workspace`
                    : "/vendors";

                return (
                  <Link
                    key={idx}
                    href={href}
                    className="flex items-start justify-between gap-3 rounded-xl border border-slate-800 bg-slate-950/60 px-3 py-2.5 text-xs text-slate-200 transition hover:border-emerald-400/70 hover:bg-slate-900"
                  >
                    <div>
                      <p className="text-[11px] text-slate-400">
                        <span className="font-semibold text-slate-50">
                          {item.vendorName}
                        </span>{" "}
                        {item.type === "EVIDENCE"
                          ? "uploaded evidence"
                          : "created assessment"}
                      </p>
                      <p className="mt-0.5 text-xs font-medium text-slate-50">
                        {item.title}
                      </p>
                      {item.type === "EVIDENCE" && item.kind && (
                        <p className="mt-0.5 text-[11px] text-slate-500">
                          {item.kind}
                        </p>
                      )}
                    </div>
                    <p className="text-[11px] text-slate-500 whitespace-nowrap">
                      {formatDate(item.at)}
                    </p>
                  </Link>
                );
              })}
            </div>
          </div>
        </section>
      </div>
    </main>
  );
}
