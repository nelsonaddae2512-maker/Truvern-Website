// app/vendors/[id]/findings/page.tsx
import Link from "next/link";
import prisma from "@/lib/prisma";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

function fmtDate(d?: Date | string | null) {
  if (!d) return "—";
  const dt = typeof d === "string" ? new Date(d) : d;
  return dt.toLocaleDateString(undefined, { year: "numeric", month: "short", day: "numeric" });
}

function sevTone(sev: string) {
  const s = String(sev || "").toUpperCase();
  if (s === "CRITICAL") return "border-rose-500/30 bg-rose-500/10 text-rose-100";
  if (s === "HIGH") return "border-amber-500/30 bg-amber-500/10 text-amber-100";
  if (s === "MEDIUM") return "border-sky-500/30 bg-sky-500/10 text-sky-100";
  return "border-slate-700 bg-slate-900/60 text-slate-200";
}

function statusTone(st: string) {
  const s = String(st || "").toUpperCase();
  if (s === "RESOLVED") return "border-emerald-500/25 bg-emerald-500/10 text-emerald-100";
  if (s === "IN_REVIEW") return "border-sky-500/25 bg-sky-500/10 text-sky-100";
  if (s === "ACCEPTED_RISK") return "border-amber-500/25 bg-amber-500/10 text-amber-100";
  return "border-white/10 bg-white/5 text-slate-100";
}

export default async function VendorFindingsPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const vendorId = Number(id);

  if (!Number.isFinite(vendorId)) {
    return (
      <main className="container-page py-12">
        <h1 className="text-2xl font-semibold">Invalid vendor id</h1>
      </main>
    );
  }

  const vendor = await prisma.vendor.findUnique({
    where: { id: vendorId },
    select: { id: true, name: true },
  });

  if (!vendor) {
    return (
      <main className="container-page py-12">
        <h1 className="text-2xl font-semibold">Vendor not found</h1>
        <Link className="mt-4 inline-block underline" href="/vendors">
          Back to Vendors
        </Link>
      </main>
    );
  }

  // ✅ Match the Vendor page logic: "open" = status !== RESOLVED
  const issues = await prisma.issue.findMany({
    where: {
      vendorId: vendor.id,
      status: { not: "RESOLVED" as any },
    } as any,
    orderBy: [
      { severity: "desc" as any }, // Prisma enum ordering can be odd; we also show severity badge
      { dueAt: "asc" as any },
      { createdAt: "desc" as any },
      { id: "desc" as any },
    ],
    include: {
      assessment: { select: { id: true, title: true } },
    },
    take: 200,
  });

  const openCount = issues.length;
  const criticalCount = issues.filter((i) => String(i.severity) === "CRITICAL").length;

  return (
    <main className="container-page py-12">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <div className="text-xs text-slate-400">Vendor Findings</div>
          <h1 className="mt-1 text-3xl font-semibold tracking-tight text-slate-50">
            {vendor.name}
          </h1>

          <div className="mt-2 flex flex-wrap items-center gap-2 text-sm text-slate-200/70">
            <span className="inline-flex items-center rounded-full border border-white/10 bg-white/5 px-3 py-1 text-[11px] font-semibold text-slate-100">
              Open findings: {openCount}
            </span>
            {criticalCount > 0 ? (
              <span className="inline-flex items-center rounded-full border border-rose-500/30 bg-rose-500/10 px-3 py-1 text-[11px] font-semibold text-rose-100">
                Critical: {criticalCount}
              </span>
            ) : null}
          </div>
        </div>

        <div className="flex gap-2">
          <Link
            href={`/vendors/${vendor.id}`}
            className="rounded-md border border-slate-800 bg-slate-900 px-3 py-2 text-sm text-slate-100 hover:bg-slate-800"
          >
            Back to Vendor
          </Link>
          <Link
            href="/issues"
            className="rounded-md border border-slate-800 bg-slate-900 px-3 py-2 text-sm text-slate-100 hover:bg-slate-800"
          >
            Global Issues
          </Link>
        </div>
      </div>

      <section className="mt-6 rounded-2xl border border-slate-800 bg-slate-950/70 p-4">
        {issues.length === 0 ? (
          <div className="rounded-xl border border-dashed border-white/10 bg-black/20 p-6 text-sm text-slate-200/70">
            No open findings found for this vendor.
          </div>
        ) : (
          <div className="divide-y divide-white/5 overflow-hidden rounded-xl border border-white/10">
            {issues.map((iss: any) => (
              <div key={iss.id} className="px-4 py-4 hover:bg-white/5">
                <div className="flex flex-col gap-2 sm:flex-row sm:items-start sm:justify-between">
                  <div className="min-w-0">
                    <div className="flex flex-wrap items-center gap-2">
                      <div className="truncate text-base font-semibold text-slate-50">
                        {iss.title ?? `Issue #${iss.id}`}
                      </div>

                      <span
                        className={`inline-flex items-center rounded-full border px-2.5 py-1 text-[11px] font-semibold ${sevTone(
                          String(iss.severity)
                        )}`}
                      >
                        {String(iss.severity)}
                      </span>

                      <span
                        className={`inline-flex items-center rounded-full border px-2.5 py-1 text-[11px] font-semibold ${statusTone(
                          String(iss.status)
                        )}`}
                      >
                        {String(iss.status)}
                      </span>
                    </div>

                    {iss.description ? (
                      <div className="mt-2 text-sm text-slate-200/70 whitespace-pre-wrap">
                        {iss.description}
                      </div>
                    ) : null}

                    <div className="mt-2 flex flex-wrap items-center gap-3 text-xs text-slate-200/60">
                      <span>Opened: {fmtDate(iss.openedAt ?? iss.createdAt)}</span>
                      <span>Due: {fmtDate(iss.dueAt)}</span>
                      <span>Updated: {fmtDate(iss.updatedAt)}</span>
                      {iss.assessment?.id ? (
                        <span className="text-slate-200/70">
                          Assessment:{" "}
                          <Link
                            href={`/assessment/runs/${iss.assessment.id}`}
                            className="text-sky-200 hover:underline"
                          >
                            {iss.assessment.title ?? `Run #${iss.assessment.id}`}
                          </Link>
                        </span>
                      ) : null}
                    </div>
                  </div>

                  {/* Optional: if you have /issues/[id] route, link it */}
                  <div className="shrink-0">
                    <Link
                      href={`/issues?vendorId=${vendor.id}`}
                      className="inline-flex items-center rounded-full border border-white/10 bg-white/5 px-3 py-2 text-xs font-semibold text-slate-100 hover:bg-white/10"
                    >
                      View in Issues ↗
                    </Link>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </section>
    </main>
  );
}
