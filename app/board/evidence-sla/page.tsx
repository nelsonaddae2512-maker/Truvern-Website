// app/board/evidence-sla/page.tsx
import Link from "next/link";
import prisma from "@/lib/prisma";
import { requireDbOrganization } from "@/lib/org-db";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

function clsx(...parts: Array<string | false | null | undefined>) {
  return parts.filter(Boolean).join(" ");
}

function fmtPct(n: number) {
  if (!Number.isFinite(n)) return "—";
  return `${Math.round(n * 100)}%`;
}

function msToDays(ms: number) {
  return ms / (1000 * 60 * 60 * 24);
}

export default async function EvidenceSlaBoardPage() {
  const org = await requireDbOrganization();
  const now = new Date();
  const soon = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);

  const rows = await prisma.evidenceRequest.findMany({
    where: { organizationId: org.id },
    select: {
      id: true,
      label: true,
      status: true,
      dueAt: true,
      submittedAt: true,
      reviewedAt: true,
      updatedAt: true,
      vendor: { select: { id: true, name: true } },
    },
    take: 1000,
    orderBy: [{ updatedAt: "desc" }],
  });

  const isOpen = (s: string) => !["APPROVED", "REJECTED", "CANCELLED", "FULFILLED", "COMPLETED"].includes((s || "").toUpperCase());

  const total = rows.length;
  const open = rows.filter((r) => isOpen(r.status)).length;
  const overdue = rows.filter((r) => isOpen(r.status) && r.dueAt && new Date(r.dueAt).getTime() < now.getTime()).length;
  const dueSoon = rows.filter(
    (r) => isOpen(r.status) && r.dueAt && new Date(r.dueAt).getTime() >= now.getTime() && new Date(r.dueAt).getTime() <= soon.getTime()
  ).length;

  // Review SLA: submitted -> reviewed
  const reviewed = rows.filter((r) => r.submittedAt && r.reviewedAt);
  const avgReviewDays =
    reviewed.length === 0
      ? null
      : reviewed.reduce((acc, r) => acc + msToDays(new Date(r.reviewedAt as any).getTime() - new Date(r.submittedAt as any).getTime()), 0) /
        reviewed.length;

  // On-time: reviewed (or approved/rejected) by due date
  const withDue = rows.filter((r) => r.dueAt);
  const onTime =
    withDue.length === 0
      ? null
      : withDue.filter((r) => {
          const due = new Date(r.dueAt as any).getTime();
          const doneAt =
            (r.reviewedAt ? new Date(r.reviewedAt as any).getTime() : null) ??
            (["APPROVED", "REJECTED"].includes((r.status || "").toUpperCase()) ? new Date(r.updatedAt as any).getTime() : null);
          return doneAt != null && doneAt <= due;
        }).length / withDue.length;

  const kpiCard = (title: string, value: string, sub?: string) => (
    <div className="glass-soft rounded-2xl border border-white/10 p-4">
      <div className="text-xs opacity-70">{title}</div>
      <div className="text-2xl font-semibold mt-1">{value}</div>
      {sub ? <div className="text-xs opacity-60 mt-1">{sub}</div> : null}
    </div>
  );

  return (
    <main className="container-page py-10">
      <div className="flex items-start justify-between gap-4">
        <div>
          <h1 className="text-2xl font-semibold">Board: Evidence SLA Metrics</h1>
          <p className="text-sm opacity-70 mt-1">Overdue, due-soon, and review turnaround performance.</p>
        </div>
        <Link className="btn-glass" href="/evidence">
          View Evidence Inbox
        </Link>
      </div>

      <div className="grid gap-4 mt-6 sm:grid-cols-2 lg:grid-cols-4">
        {kpiCard("Total requests", String(total))}
        {kpiCard("Open requests", String(open))}
        {kpiCard("Overdue (CRITICAL)", String(overdue))}
        {kpiCard("Due in next 7 days", String(dueSoon))}
        {kpiCard("On-time completion rate", onTime == null ? "—" : fmtPct(onTime), "Based on requests with due dates")}
        {kpiCard("Avg review turnaround", avgReviewDays == null ? "—" : `${avgReviewDays.toFixed(1)} days`, "Submitted → Reviewed")}
      </div>

      <div className="mt-6 glass-soft rounded-2xl border border-white/10 overflow-hidden">
        <div className="px-4 py-3 bg-white/5 text-sm font-medium">Most recent requests</div>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="bg-white/5">
              <tr className="text-left">
                <th className="px-4 py-3 font-medium">Request</th>
                <th className="px-4 py-3 font-medium">Vendor</th>
                <th className="px-4 py-3 font-medium">Status</th>
                <th className="px-4 py-3 font-medium">Due</th>
                <th className="px-4 py-3 font-medium">Updated</th>
              </tr>
            </thead>
            <tbody>
              {rows.slice(0, 25).map((r) => (
                <tr key={r.id} className="border-t border-white/10 hover:bg-white/5">
                  <td className="px-4 py-3">
                    <Link className="underline-offset-4 hover:underline" href={`/org/evidence-requests/${r.id}`}>
                      {r.label || `Request #${r.id}`}
                    </Link>
                  </td>
                  <td className="px-4 py-3">
                    {r.vendor ? (
                      <Link className="underline-offset-4 hover:underline" href={`/vendors/${r.vendor.id}`}>
                        {r.vendor.name}
                      </Link>
                    ) : (
                      <span className="opacity-60">—</span>
                    )}
                  </td>
                  <td className="px-4 py-3">{r.status}</td>
                  <td className="px-4 py-3">{r.dueAt ? new Date(r.dueAt as any).toLocaleDateString() : "—"}</td>
                  <td className="px-4 py-3">{new Date(r.updatedAt as any).toLocaleDateString()}</td>
                </tr>
              ))}
              {rows.length === 0 && (
                <tr>
                  <td className="px-4 py-10 opacity-70" colSpan={5}>
                    No evidence requests yet.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
    </main>
  );
}
