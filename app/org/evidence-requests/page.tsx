// app/org/evidence-requests/page.tsx
import Link from "next/link";
import prisma from "@/lib/prisma";
import { revalidatePath } from "next/cache";
import EvidenceRequestStatusBadge from "@/components/evidence-request-status-badge";

export const dynamic = "force-dynamic";
export const revalidate = 0;

function fmtDate(d?: Date | string | null) {
  if (!d) return "—";
  const dt = typeof d === "string" ? new Date(d) : d;
  return dt.toLocaleDateString(undefined, { year: "numeric", month: "short", day: "numeric" });
}

function NeedsReviewBadge({ status }: { status: string }) {
  if (status !== "SUBMITTED") return null;
  return (
    <span className="inline-flex items-center rounded-full border border-amber-400/40 bg-amber-500/10 px-2.5 py-1 text-[11px] font-semibold text-amber-200">
      Needs review
    </span>
  );
}

export default async function OrgEvidenceRequestsPage() {
  async function approveInline(formData: FormData) {
    "use server";
    const id = Number(formData.get("id"));
    if (!id || Number.isNaN(id)) return;

    const reqRow = await prisma.evidenceRequest.findUnique({ where: { id }, select: { status: true } });
    if (!reqRow || String(reqRow.status) !== "SUBMITTED") return;

    const latestIter = await prisma.evidenceRequestIteration.findFirst({
      where: { evidenceRequestId: id },
      orderBy: [{ submittedAt: "desc" }, { id: "desc" }],
      select: { id: true },
    });

    await prisma.$transaction(async (tx) => {
      await tx.evidenceRequest.update({
        where: { id },
        data: { status: "APPROVED" as any, reviewedAt: new Date() } as any,
      });
      if (latestIter?.id) {
        await tx.evidenceRequestIteration.update({
          where: { id: latestIter.id },
          data: { status: "APPROVED" as any, reviewedAt: new Date() } as any,
        });
      }
    });

    revalidatePath("/org/evidence-requests");
  }

  async function rejectInline(formData: FormData) {
    "use server";
    const id = Number(formData.get("id"));
    const note = String(formData.get("reviewNote") ?? "").trim();
    if (!id || Number.isNaN(id)) return;

    const reqRow = await prisma.evidenceRequest.findUnique({ where: { id }, select: { status: true } });
    if (!reqRow || String(reqRow.status) !== "SUBMITTED") return;

    const latestIter = await prisma.evidenceRequestIteration.findFirst({
      where: { evidenceRequestId: id },
      orderBy: [{ submittedAt: "desc" }, { id: "desc" }],
      select: { id: true },
    });

    const message = note || "Rejected — please resubmit with the requested updates.";

    await prisma.$transaction(async (tx) => {
      await tx.evidenceRequest.update({
        where: { id },
        data: { status: "REJECTED" as any, reviewedAt: new Date(), reviewNote: message } as any,
      });
      if (latestIter?.id) {
        await tx.evidenceRequestIteration.update({
          where: { id: latestIter.id },
          data: { status: "REJECTED" as any, reviewedAt: new Date(), reviewerNote: message } as any,
        });
      }
    });

    revalidatePath("/org/evidence-requests");
  }

  const rows = await prisma.evidenceRequest.findMany({
    orderBy: [{ updatedAt: "desc" }, { id: "desc" }],
    include: {
      vendor: { select: { id: true, name: true } },
      iterations: {
        orderBy: [{ submittedAt: "desc" as any }, { id: "desc" as any }] as any,
        take: 1,
        include: {
          files: { select: { id: true } },
        },
      },
    },
    take: 200,
  });

  return (
    <main className="relative max-w-6xl mx-auto px-4 lg:px-6 py-12 lg:py-16">
      <div className="flex items-center justify-between gap-3">
        <div>
          <div className="text-[11px] font-semibold uppercase tracking-[0.18em] text-slate-400">
            Organization
          </div>
          <h1 className="mt-1 text-3xl font-semibold tracking-tight text-slate-50">
            Evidence requests
          </h1>
          <p className="mt-2 text-sm text-slate-200/70">
            Review vendor submissions and approve or request improvements.
          </p>
        </div>

        <Link
          href="/vendors"
          className="rounded-full border border-white/10 bg-white/5 px-4 py-2 text-sm font-semibold text-slate-100 hover:bg-white/10"
        >
          Vendor portfolio ↗
        </Link>
      </div>

      <div className="mt-6 overflow-hidden rounded-3xl border border-slate-800 bg-slate-950/80">
        {rows.length === 0 ? (
          <div className="p-6 text-sm text-slate-200/60">No evidence requests yet.</div>
        ) : (
          <div className="divide-y divide-white/5">
            {rows.map((r: any) => {
              const status = String(r.status ?? "OPEN");
              const fileCount = r.iterations?.[0]?.files?.length ?? 0;

              return (
                <div key={r.id} className="p-5">
                  <div className="flex flex-col gap-3 md:flex-row md:items-start md:justify-between">
                    <div className="min-w-0">
                      <div className="flex flex-wrap items-center gap-2">
                        <Link
                          href={`/org/evidence-requests/${r.id}`}
                          className="truncate text-base font-semibold text-slate-50 hover:underline"
                        >
                          {r.label ?? `Evidence request #${r.id}`}
                        </Link>

                        <EvidenceRequestStatusBadge status={status as any} />
                        <NeedsReviewBadge status={status} />

                        <span className="text-xs text-slate-200/60">
                          Files: <span className="text-slate-100 font-semibold">{fileCount}</span>
                        </span>
                      </div>

                      <div className="mt-2 flex flex-wrap items-center gap-3 text-sm text-slate-200/70">
                        <span>
                          Vendor:{" "}
                          <span className="text-slate-50 font-semibold">{r.vendor?.name ?? "—"}</span>
                        </span>
                        <span>Due: {fmtDate(r.dueAt)}</span>
                        <span>Submitted: {fmtDate(r.submittedAt)}</span>
                        <span>Reviewed: {fmtDate(r.reviewedAt)}</span>
                      </div>
                    </div>

                    <div className="flex flex-wrap items-center gap-2">
                      <Link
                        href={`/org/evidence-requests/${r.id}`}
                        className="rounded-full border border-white/10 bg-white/5 px-4 py-2 text-sm font-semibold text-slate-100 hover:bg-white/10"
                      >
                        Review ↗
                      </Link>

                      {status === "SUBMITTED" ? (
                        <>
                          <form action={approveInline}>
                            <input type="hidden" name="id" value={String(r.id)} />
                            <button
                              type="submit"
                              className="rounded-full bg-emerald-500 px-4 py-2 text-sm font-semibold text-slate-950 hover:bg-emerald-400"
                            >
                              Approve
                            </button>
                          </form>

                          <form action={rejectInline} className="flex items-center gap-2">
                            <input type="hidden" name="id" value={String(r.id)} />
                            <input
                              name="reviewNote"
                              placeholder="Reject note (optional)"
                              className="hidden md:block w-56 rounded-full border border-white/10 bg-black/30 px-3 py-2 text-sm text-slate-50 outline-none placeholder:text-slate-200/40"
                            />
                            <button
                              type="submit"
                              className="rounded-full border border-rose-500/40 bg-rose-500/10 px-4 py-2 text-sm font-semibold text-rose-100 hover:bg-rose-500/15"
                            >
                              Reject
                            </button>
                          </form>
                        </>
                      ) : null}

                      {r.vendor?.id ? (
                        <Link
                          href={`/vendors/${r.vendor.id}`}
                          className="rounded-full border border-sky-400/40 bg-sky-500/10 px-4 py-2 text-sm font-semibold text-sky-200 hover:bg-sky-500/15"
                        >
                          View vendor ↗
                        </Link>
                      ) : null}
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </main>
  );
}
