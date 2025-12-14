// app/assessment/page.tsx
import Link from "next/link";
import prisma from "@/lib/prisma";
import { SignedIn, SignedOut } from "@clerk/nextjs";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

function clsx(...parts: Array<string | false | null | undefined>) {
  return parts.filter(Boolean).join(" ");
}

function fmtDate(d?: Date | string | null) {
  if (!d) return "—";
  const dt = typeof d === "string" ? new Date(d) : d;
  if (Number.isNaN(dt.getTime())) return "—";
  return dt.toLocaleDateString(undefined, { year: "numeric", month: "short", day: "numeric" });
}

function statusTone(status: string) {
  const s = String(status || "").toUpperCase();
  if (s.includes("IN_PROGRESS")) return "border-sky-500/30 bg-sky-500/10 text-sky-200";
  if (s.includes("COMPLETE") || s.includes("DONE")) return "border-emerald-500/30 bg-emerald-500/10 text-emerald-200";
  if (s.includes("CANCEL") || s.includes("ARCHIVE")) return "border-slate-500/30 bg-slate-500/10 text-slate-200";
  return "border-white/10 bg-white/5 text-slate-200/80";
}

export default async function AssessmentPage() {
  const RunModel: any = (prisma as any).assessmentRun ?? (prisma as any).assessment;

  const runs: any[] = RunModel
    ? await RunModel.findMany({
        orderBy: [{ updatedAt: "desc" as any }, { id: "desc" as any }],
        take: 50,
        include: {
          vendor: { select: { id: true, name: true } },
        },
      }).catch(() => [])
    : [];

  return (
    <main className="container-page py-10">
      <div className="mb-6">
        <div className="text-xs font-semibold tracking-wider text-emerald-200/90">ASSESSMENT</div>
        <h1 className="mt-2 text-3xl font-semibold tracking-tight text-slate-50">Assessment</h1>
        <p className="mt-2 text-sm text-slate-200/70">
          Build templates, manage question banks, and run structured vendor assessments.
        </p>
      </div>

      {/* Your existing tabs appear to be in a layout component; this page focuses on the Runs card content. */}
      <div className="rounded-2xl border border-white/10 bg-white/5 p-6">
        <div className="text-xs font-semibold tracking-wider text-slate-200/60">ASSESSMENTS</div>
        <div className="mt-1 text-2xl font-semibold text-slate-50">Assessment Runs</div>

        <SignedOut>
          <p className="mt-2 text-sm text-slate-200/70">Please sign in to view assessment runs.</p>
          <div className="mt-4 flex gap-2">
            <Link
              href="/sign-in"
              className="rounded-lg border border-white/10 bg-white/5 px-4 py-2 text-sm font-semibold text-slate-50 hover:bg-white/10"
            >
              Sign in
            </Link>
            <Link
              href="/"
              className="rounded-lg border border-white/10 bg-white/5 px-4 py-2 text-sm font-semibold text-slate-50 hover:bg-white/10"
            >
              Back home
            </Link>
          </div>
        </SignedOut>

        <SignedIn>
          {runs.length === 0 ? (
            <div className="mt-4 text-sm text-slate-200/70">
              No runs found yet.
              <div className="mt-1 text-xs text-slate-200/50">
                Your seed output says you created <span className="font-semibold">Run #5</span>. Try opening{" "}
                <Link className="text-emerald-200/90 hover:text-emerald-200" href="/assessment/runs/5">
                  /assessment/runs/5
                </Link>
                .
              </div>
            </div>
          ) : (
            <div className="mt-4 overflow-hidden rounded-xl border border-white/10">
              <div className="grid grid-cols-12 gap-2 border-b border-white/10 bg-black/20 px-4 py-2 text-[11px] font-semibold text-slate-200/70">
                <div className="col-span-5">Run</div>
                <div className="col-span-4">Vendor</div>
                <div className="col-span-2">Status</div>
                <div className="col-span-1 text-right">ID</div>
              </div>

              <div className="divide-y divide-white/10">
                {runs.map((r) => {
                  const id = r?.id;
                  const title = r?.title ?? `Run #${id}`;
                  const status = String(r?.status ?? "UNKNOWN");
                  const vendorName = r?.vendor?.name ?? "—";
                  const updated = r?.updatedAt ?? r?.createdAt ?? null;

                  return (
                    <Link
                      key={id}
                      href={`/assessment/runs/${id}`}
                      className="grid grid-cols-12 gap-2 px-4 py-3 hover:bg-white/5"
                    >
                      <div className="col-span-5 min-w-0">
                        <div className="truncate text-sm font-semibold text-slate-50">{title}</div>
                        <div className="mt-0.5 text-xs text-slate-200/60">Updated: {fmtDate(updated)}</div>
                      </div>

                      <div className="col-span-4 min-w-0">
                        <div className="truncate text-sm font-semibold text-slate-50">{vendorName}</div>
                        {r?.vendor?.id ? (
                          <div className="mt-0.5 text-xs text-slate-200/60">Vendor #{r.vendor.id}</div>
                        ) : (
                          <div className="mt-0.5 text-xs text-slate-200/60">—</div>
                        )}
                      </div>

                      <div className="col-span-2">
                        <span
                          className={clsx(
                            "inline-flex items-center rounded-full border px-2.5 py-1 text-[11px] font-semibold",
                            statusTone(status)
                          )}
                        >
                          {status}
                        </span>
                      </div>

                      <div className="col-span-1 text-right text-xs text-slate-200/60">#{id}</div>
                    </Link>
                  );
                })}
              </div>
            </div>
          )}
        </SignedIn>
      </div>
    </main>
  );
}
