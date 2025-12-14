// app/activity/page.tsx

import Link from "next/link";
import prisma from "@/lib/prisma";

type ActivityItem = {
  vendorId: number;
  vendorName: string;
  kind: "evidence" | "assessment";
  label: string;
  timestamp: Date;
  accent: string;
};

function formatDateTime(d: Date) {
  return d.toLocaleString(undefined, {
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export const metadata = {
  title: "Activity – Truvern",
  description:
    "Lightweight activity feed showing recent evidence uploads and assessment updates across your vendor portfolio.",
};

async function getActivityFeed(): Promise<ActivityItem[]> {
  const [recentEvidence, recentAssessments] = await Promise.all([
    prisma.evidence.findMany({
      orderBy: { uploadedAt: "desc" },
      take: 20,
      include: {
        vendor: { select: { id: true, name: true } },
      },
    }),
    prisma.assessment.findMany({
      orderBy: { createdAt: "desc" },
      take: 20,
      include: {
        vendor: { select: { id: true, name: true } },
      },
    }),
  ]);

  const evidenceItems: ActivityItem[] = recentEvidence
    .filter((e) => e.vendor)
    .map((e) => ({
      vendorId: e.vendor!.id,
      vendorName: e.vendor!.name,
      kind: "evidence",
      label: e.title || "New evidence added",
      timestamp: e.uploadedAt ?? new Date(),
      accent: e.kind || "Evidence",
    }));

  const assessmentItems: ActivityItem[] = recentAssessments
    .filter((a) => a.vendor)
    .map((a) => ({
      vendorId: a.vendor!.id,
      vendorName: a.vendor!.name,
      kind: "assessment",
      label: "Assessment updated",
      timestamp: a.createdAt,
      accent: "Assessment",
    }));

  const merged = [...evidenceItems, ...assessmentItems];

  merged.sort((a, b) => b.timestamp.getTime() - a.timestamp.getTime());

  return merged.slice(0, 30);
}

export default async function ActivityPage() {
  const activityFeed = await getActivityFeed();

  return (
    <main className="relative max-w-5xl mx-auto px-4 lg:px-6 py-12 lg:py-16">
      {/* Soft background glow */}
      <div className="pointer-events-none absolute inset-x-0 -top-32 -z-10 h-64 bg-[radial-gradient(circle_at_top,_rgba(45,212,191,0.25),transparent_60%)]" />
      <div className="pointer-events-none absolute inset-x-0 bottom-0 -z-10 h-64 bg-[radial-gradient(circle_at_bottom,_rgba(56,189,248,0.20),transparent_60%)]" />

      {/* Accent line */}
      <div className="h-px w-full bg-gradient-to-r from-emerald-400/80 via-cyan-400/70 to-violet-500/70 mb-6" />

      {/* Header */}
      <section className="flex flex-col gap-4 md:flex-row md:items-center md:justify-between mb-6">
        <div className="space-y-3">
          <div className="inline-flex items-center gap-2 rounded-full bg-slate-900/70 border border-emerald-500/30 px-3 py-1">
            <span className="h-1.5 w-1.5 rounded-full bg-emerald-400 animate-pulse" />
            <span className="text-[10px] font-semibold tracking-[0.2em] text-emerald-300 uppercase">
              Truvern activity
            </span>
          </div>
          <div>
            <h1 className="text-2xl md:text-3xl font-semibold text-slate-50 tracking-tight">
              Recent activity
            </h1>
            <p className="mt-2 max-w-xl text-sm text-slate-300">
              A lightweight feed of what&apos;s changing across your vendor
              space — new evidence, refreshed assessments, and quiet proof that
              the program is alive.
            </p>
          </div>
        </div>

        <div className="flex flex-col items-start md:items-end gap-2 text-xs text-slate-400">
          <p>
            Tip: For a board-ready snapshot, use the{" "}
            <Link
              href="/board-report"
              className="text-emerald-300 hover:text-emerald-200"
            >
              Board Report
            </Link>{" "}
            view.
          </p>
          <p>
            For vendor-level details, jump into the{" "}
            <Link
              href="/vendors"
              className="text-emerald-300 hover:text-emerald-200"
            >
              Vendor workspace
            </Link>
            .
          </p>
        </div>
      </section>

      {/* Activity list */}
      {activityFeed.length === 0 ? (
        <section>
          <p className="text-sm text-slate-500 border border-dashed border-slate-700 rounded-2xl px-4 py-6 bg-slate-950/60">
            No recent activity yet. As you upload evidence and complete
            assessments, Truvern will begin to show a calm stream of updates
            here.
          </p>
        </section>
      ) : (
        <section className="rounded-2xl border border-slate-800/80 bg-slate-950/70 divide-y divide-slate-800/80">
          {activityFeed.map((item, idx) => (
            <Link
              key={`${item.vendorId}-${item.kind}-${idx}-${item.timestamp.toISOString()}`}
              href={`/vendors/${item.vendorId}`}
              className="flex items-center justify-between gap-3 px-4 py-3 hover:bg-slate-900/80 transition"
            >
              <div className="flex items-center gap-3 min-w-0">
                <div className="flex h-9 w-9 items-center justify-center rounded-full bg-slate-900 border border-slate-700 text-sm">
                  {item.kind === "evidence" ? "📄" : "📝"}
                </div>
                <div className="flex flex-col min-w-0">
                  <span className="text-xs font-semibold text-slate-100 truncate">
                    {item.vendorName}
                  </span>
                  <span className="text-[11px] text-slate-300 truncate">
                    {item.kind === "evidence"
                      ? `Added evidence: ${item.label}`
                      : item.label}
                  </span>
                </div>
              </div>
              <div className="flex flex-col items-end gap-1 shrink-0">
                <span className="inline-flex items-center rounded-full border border-slate-700 bg-slate-900/70 px-2 py-0.5 text-[10px] uppercase tracking-[0.16em] text-slate-400">
                  {item.accent}
                </span>
                <span className="text-[10px] text-slate-500">
                  {formatDateTime(item.timestamp)}
                </span>
              </div>
            </Link>
          ))}
        </section>
      )}
    </main>
  );
}
