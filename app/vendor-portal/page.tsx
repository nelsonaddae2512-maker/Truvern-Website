// app/vendor-portal/page.tsx
import Link from "next/link";
import prisma from "@/lib/prisma";
import { auth, currentUser } from "@clerk/nextjs/server";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

function devBypassEnabled() {
  return process.env.NODE_ENV !== "production" && process.env.TRUVERN_DEV_BYPASS_AUTH === "1";
}

async function resolveVendorId(): Promise<number | null> {
  if (devBypassEnabled()) {
    const v = Number(process.env.TRUVERN_DEV_VENDOR_ID ?? "");
    return Number.isFinite(v) ? v : null;
  }

  const { userId } = auth();
  if (!userId) return null;

  const user = await currentUser();
  const vendorIdRaw = (user?.publicMetadata as any)?.vendorId;

  const vendorId =
    typeof vendorIdRaw === "number"
      ? vendorIdRaw
      : typeof vendorIdRaw === "string"
      ? Number(vendorIdRaw)
      : NaN;

  return Number.isFinite(vendorId) ? vendorId : null;
}

function fmt(value?: Date | string | null) {
  if (!value) return "";
  const d = typeof value === "string" ? new Date(value) : value;
  if (Number.isNaN(d.getTime())) return "";
  return d.toLocaleDateString(undefined, {
    year: "numeric",
    month: "short",
    day: "2-digit",
  });
}

function clsx(...parts: Array<string | false | null | undefined>) {
  return parts.filter(Boolean).join(" ");
}

function statusTone(status: string) {
  const s = String(status || "").toUpperCase();
  if (s.includes("IN_PROGRESS")) return "border-sky-500/30 bg-sky-500/10 text-sky-200";
  if (s.includes("COMPLETE") || s.includes("DONE")) return "border-emerald-500/30 bg-emerald-500/10 text-emerald-200";
  if (s.includes("CANCEL") || s.includes("ARCHIVE")) return "border-slate-500/30 bg-slate-500/10 text-slate-200";
  return "border-white/10 bg-white/5 text-slate-200/80";
}

export default async function VendorPortalPage() {
  const vendorId = await resolveVendorId();

  if (!vendorId) {
    return (
      <main className="max-w-5xl mx-auto px-4 py-12">
        <div className="rounded-2xl border border-white/10 bg-slate-950/40 p-6">
          <div className="text-xs tracking-[0.28em] text-emerald-200/70">VENDOR PORTAL</div>
          <h1 className="mt-2 text-2xl font-semibold text-slate-50">Sign in required</h1>
          <p className="mt-2 text-sm text-slate-200/70">
            This area is restricted to vendor users. If you’re testing locally, you can set{" "}
            <span className="font-semibold">TRUVERN_DEV_BYPASS_AUTH=1</span> and{" "}
            <span className="font-semibold">TRUVERN_DEV_VENDOR_ID</span>.
          </p>

          <div className="mt-4">
            <Link
              href="/sign-in"
              className="inline-flex items-center justify-center rounded-full bg-emerald-500 px-4 py-2 text-sm font-semibold text-slate-950 hover:bg-emerald-400"
            >
              Sign in ↗
            </Link>
          </div>
        </div>
      </main>
    );
  }

  // --- Compute vendor + tasks (existing concept) ---
  const vendor = await prisma.vendor.findUnique({
    where: { id: vendorId },
    include: {
      organization: true,
      trustProfile: true,
    },
  });

  if (!vendor) {
    return (
      <main className="max-w-5xl mx-auto px-4 py-12">
        <div className="rounded-2xl border border-white/10 bg-slate-950/40 p-6">
          <h1 className="text-2xl font-semibold text-slate-50">Vendor not found</h1>
          <p className="mt-2 text-sm text-slate-200/70">
            Your vendor account is not linked to a valid Vendor record.
          </p>
          <div className="mt-4">
            <Link
              href="/"
              className="inline-flex items-center justify-center rounded-full border border-white/10 bg-white/5 px-4 py-2 text-sm font-medium text-slate-100 hover:bg-white/10"
            >
              Back home ↗
            </Link>
          </div>
        </div>
      </main>
    );
  }

  // Minimal “tasks” concept — keep as-is if you already had vendor tasks elsewhere
  // If you already have a vendor tasks query in your file, keep it and remove this block.
  const tasks = [
    { label: "Keep profile up to date", status: "ACTIVE" },
    { label: "Respond to evidence requests", status: "ACTIVE" },
  ];

  // ✅ Phase 321B — evidence requests query (exactly as requested)
  const evidenceRequests = await prisma.evidenceRequest.findMany({
    where: { vendorId: vendor.id, status: { in: ["OPEN", "REJECTED"] } as any },
    orderBy: [{ dueAt: "asc" as any }, { updatedAt: "desc" as any }],
    take: 20,
  });

  // ✅ Vendor assessments (best-effort; supports prisma.assessmentRun OR prisma.assessment)
  const RunModel: any = (prisma as any).assessmentRun ?? (prisma as any).assessment;
  const recentRuns: any[] =
    RunModel?.findMany
      ? await RunModel.findMany({
          where: { vendorId: vendor.id },
          orderBy: [{ updatedAt: "desc" as any }, { id: "desc" as any }],
          take: 6,
          select: {
            id: true,
            title: true,
            status: true,
            updatedAt: true,
            createdAt: true,
          },
        }).catch(() => [])
      : [];

  const openRunsCount =
    RunModel?.count
      ? await RunModel.count({ where: { vendorId: vendor.id, status: "IN_PROGRESS" } }).catch(() => 0)
      : 0;

  return (
    <main className="relative max-w-6xl mx-auto px-4 lg:px-6 py-12 lg:py-16">
      <div className="pointer-events-none absolute inset-x-0 -top-32 -z-10 h-64 bg-[radial-gradient(circle_at_top,_rgba(45,212,191,0.18),transparent_60%)]" />

      <div className="mb-6 rounded-3xl border border-white/10 bg-slate-950/40 p-6">
        <div className="flex flex-col gap-3 md:flex-row md:items-start md:justify-between">
          <div>
            <div className="text-xs tracking-[0.28em] text-emerald-200/70">VENDOR PORTAL</div>
            <h1 className="mt-2 text-3xl font-semibold text-slate-50">Welcome, {vendor.name}</h1>
            <p className="mt-2 text-sm text-slate-200/70">
              Customer:{" "}
              <span className="font-semibold text-slate-100">{vendor.organization?.name ?? "—"}</span>
              {vendor.trustProfile?.headline ? (
                <>
                  {" "}
                  • <span className="text-slate-200/60">{vendor.trustProfile.headline}</span>
                </>
              ) : null}
            </p>
          </div>

          <div className="flex flex-wrap items-center gap-2">
            {/* ✅ NEW: vendor assessments CTA */}
            <Link
              href="/vendor-portal/assessments"
              className="inline-flex items-center justify-center rounded-full bg-emerald-500 px-4 py-2 text-sm font-semibold text-slate-950 hover:bg-emerald-400"
            >
              Assessments ↗
            </Link>

            <Link
              href={`/vendors/${vendor.id}?as=vendor`}
              className="inline-flex items-center justify-center rounded-full border border-white/10 bg-white/5 px-4 py-2 text-sm font-medium text-slate-100 hover:bg-white/10"
            >
              View profile ↗
            </Link>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 gap-5 lg:grid-cols-[minmax(0,1.4fr)_minmax(0,1fr)]">
        {/* Left column */}
        <div className="space-y-5">
          {/* ✅ NEW: Assessments card */}
          <section className="rounded-3xl border border-white/10 bg-slate-950/40">
            <div className="border-b border-white/10 px-5 py-4">
              <div className="flex items-center justify-between gap-3">
                <div>
                  <div className="text-sm font-semibold text-slate-50">Assessments</div>
                  <div className="mt-1 text-xs text-slate-200/60">
                    {openRunsCount} in progress · Vendor-facing answering happens in Vendor Portal.
                  </div>
                </div>
                <Link
                  href="/vendor-portal/assessments"
                  className="inline-flex items-center justify-center rounded-full border border-white/10 bg-white/5 px-3 py-2 text-xs font-semibold text-slate-100 hover:bg-white/10"
                >
                  View all ↗
                </Link>
              </div>
            </div>

            <div className="px-5 py-4">
              {recentRuns.length === 0 ? (
                <p className="text-sm text-slate-200/70">No assessments yet.</p>
              ) : (
                <div className="space-y-2">
                  {recentRuns.map((r: any) => {
                    const updated = r.updatedAt ?? r.createdAt ?? null;
                    const title = r.title ?? `Assessment #${r.id}`;
                    const status = String(r.status ?? "UNKNOWN");

                    return (
                      <Link
                        key={r.id}
                        href={`/vendor-portal/assessments/${r.id}`}
                        className="flex items-center justify-between gap-3 rounded-xl border border-white/10 bg-slate-950/60 px-4 py-3 hover:bg-white/5"
                      >
                        <div className="min-w-0">
                          <div className="truncate text-sm font-semibold text-slate-50">{title}</div>
                          <div className="mt-1 text-xs text-slate-200/60">Updated {fmt(updated)}</div>
                        </div>

                        <div className="shrink-0 flex items-center gap-2">
                          <span
                            className={clsx(
                              "inline-flex items-center rounded-full border px-2.5 py-1 text-[11px] font-semibold",
                              statusTone(status)
                            )}
                          >
                            {status}
                          </span>
                          <span className="text-xs text-slate-200/50">#{r.id}</span>
                        </div>
                      </Link>
                    );
                  })}
                </div>
              )}
            </div>
          </section>

          <section className="rounded-3xl border border-white/10 bg-slate-950/40">
            <div className="border-b border-white/10 px-5 py-4">
              <div className="text-sm font-semibold text-slate-50">Task inbox</div>
              <div className="mt-1 text-xs text-slate-200/60">What needs your attention this week.</div>
            </div>
            <div className="px-5 py-4">
              {tasks.length === 0 ? (
                <p className="text-sm text-slate-200/70">No tasks right now.</p>
              ) : (
                <div className="space-y-2">
                  {tasks.map((t, idx) => (
                    <div
                      key={idx}
                      className="flex items-center justify-between rounded-xl border border-white/10 bg-slate-950/60 px-4 py-3"
                    >
                      <div className="text-sm text-slate-100">{t.label}</div>
                      <span className="text-xs text-emerald-200/80">Active</span>
                    </div>
                  ))}
                </div>
              )}
            </div>

            {/* ✅ Phase 321B — Evidence requests block (as requested) */}
            <div className="border-t border-white/10 px-5 py-4">
              <div className="flex items-center justify-between">
                <div className="text-sm font-semibold text-slate-50">Evidence requests</div>
                <span className="text-xs text-slate-200/60">{evidenceRequests.length} open</span>
              </div>

              {evidenceRequests.length === 0 ? (
                <p className="mt-2 text-sm text-slate-200/70">No evidence requests right now.</p>
              ) : (
                <div className="mt-3 divide-y divide-white/5 rounded-xl border border-white/10 overflow-hidden">
                  {evidenceRequests.map((r: any) => (
                    <div
                      key={r.id}
                      className="flex flex-col gap-3 px-4 py-4 md:flex-row md:items-center md:justify-between"
                    >
                      <div className="min-w-0">
                        <div className="flex flex-wrap items-center gap-2">
                          <div className="truncate text-sm font-medium text-slate-50">{r.label}</div>
                          <span className="inline-flex items-center rounded-full border border-amber-500/20 bg-amber-500/10 px-2.5 py-1 text-xs text-amber-200">
                            Action required
                          </span>
                          {r.dueAt ? (
                            <span className="text-xs text-slate-200/60">Due {fmt(r.dueAt)}</span>
                          ) : null}
                        </div>
                        {r.description ? (
                          <p className="mt-1 text-sm text-slate-200/70">{r.description}</p>
                        ) : (
                          <p className="mt-1 text-sm text-slate-200/50">No additional instructions.</p>
                        )}
                      </div>

                      <div className="flex items-center gap-2">
                        <Link
                          href={`/vendor-portal/evidence-requests/${r.id}`}
                          className="inline-flex items-center justify-center rounded-full bg-emerald-500 px-4 py-2 text-xs font-semibold text-slate-950 hover:bg-emerald-400"
                        >
                          Upload evidence ↗
                        </Link>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </section>
        </div>

        {/* Right column */}
        <aside className="space-y-5">
          <section className="rounded-3xl border border-white/10 bg-slate-950/40 px-5 py-4">
            <div className="text-[11px] font-semibold uppercase tracking-[0.18em] text-slate-400">
              Portal status
            </div>

            <div className="mt-3 space-y-2 text-sm text-slate-200/80">
              <div className="flex items-center justify-between">
                <span>Trust status</span>
                <span className="font-semibold text-emerald-200">Verified</span>
              </div>
              <div className="flex items-center justify-between">
                <span>Open requests</span>
                <span className="font-semibold text-slate-100">{evidenceRequests.length}</span>
              </div>
              <div className="flex items-center justify-between">
                <span>Assessments (in progress)</span>
                <span className="font-semibold text-slate-100">{openRunsCount}</span>
              </div>
              <div className="flex items-center justify-between">
                <span>Category</span>
                <span className="font-semibold text-slate-100">{(vendor as any).category ?? "—"}</span>
              </div>
            </div>

            <div className="mt-4 space-y-2">
              <Link
                href={`/vendor-portal/assessments`}
                className="inline-flex w-full items-center justify-center rounded-xl bg-emerald-500 px-4 py-2 text-sm font-semibold text-slate-950 hover:bg-emerald-400"
              >
                Open assessments ↗
              </Link>

              <Link
                href={`/vendors/${vendor.id}?as=vendor`}
                className="inline-flex w-full items-center justify-center rounded-xl border border-white/10 bg-white/5 px-4 py-2 text-sm font-medium text-slate-100 hover:bg-white/10"
              >
                View trust profile ↗
              </Link>
            </div>
          </section>
        </aside>
      </div>
    </main>
  );
}
