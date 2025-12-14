// app/vendor-portal/assessments/page.tsx
import Link from "next/link";
import prisma from "@/lib/prisma";
import { auth } from "@clerk/nextjs/server";

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

async function resolveVendorForUser(userId: string, email?: string | null) {
  const anyPrisma: any = prisma;

  // Prefer explicit mappings if your schema has them
  if (typeof anyPrisma.vendorUser?.findFirst === "function") {
    const vu = await anyPrisma.vendorUser
      .findFirst({
        where: { userId },
        include: { vendor: { select: { id: true, name: true } } },
      })
      .catch(() => null);
    if (vu?.vendor) return vu.vendor;
  }

  // Common direct linking field patterns
  const candidates = ["portalUserId", "userId", "clerkUserId"];
  for (const field of candidates) {
    try {
      const v = await prisma.vendor.findFirst({
        where: { [field]: userId } as any,
        select: { id: true, name: true },
      });
      if (v) return v;
    } catch {
      // ignore
    }
  }

  // Fallback: match by vendor contact email if present
  if (email) {
    const emailFields = ["contactEmail", "email", "primaryEmail"];
    for (const f of emailFields) {
      try {
        const v = await prisma.vendor.findFirst({
          where: { [f]: email } as any,
          select: { id: true, name: true },
        });
        if (v) return v;
      } catch {
        // ignore
      }
    }
  }

  // Dev-only safety net (keeps local demo working)
  return prisma.vendor
    .findFirst({ orderBy: { id: "asc" }, select: { id: true, name: true } })
    .catch(() => null);
}

async function getAnsweredCount(runId: number) {
  const anyPrisma: any = prisma;
  if (typeof anyPrisma.assessmentAnswer?.count !== "function") return null;
  return anyPrisma.assessmentAnswer.count({ where: { assessmentId: runId } }).catch(() => null);
}

async function getTotalQuestions(runId: number, templateId: number | null) {
  const anyPrisma: any = prisma;
  if (typeof anyPrisma.assessmentQuestion?.count !== "function") return null;

  // Prefer run-scoped questions if present in schema
  const hasAssessmentId = (() => {
    // cheap heuristic: try count and catch schema mismatch
    return true;
  })();

  if (hasAssessmentId) {
    const byRun = await anyPrisma.assessmentQuestion
      .count({ where: { assessmentId: runId } })
      .catch(() => null);
    if (typeof byRun === "number" && byRun > 0) return byRun;
  }

  // Fallback to template-scoped questions
  if (templateId) {
    const byTemplate = await anyPrisma.assessmentQuestion
      .count({ where: { templateId } })
      .catch(() => null);
    if (typeof byTemplate === "number") return byTemplate;
  }

  return null;
}

export default async function VendorPortalAssessmentsPage() {
  const { userId } = auth();

  if (!userId) {
    return (
      <main className="container-page py-10">
        <div className="rounded-2xl border border-white/10 bg-white/5 p-8">
          <h1 className="text-2xl font-semibold text-slate-50">Vendor assessments</h1>
          <p className="mt-2 text-sm text-slate-200/70">Please sign in to view your assessments.</p>
          <div className="mt-6">
            <Link
              href="/sign-in"
              className="rounded-lg border border-white/10 bg-white/5 px-4 py-2 text-sm font-semibold text-slate-50 hover:bg-white/10"
            >
              Sign in
            </Link>
          </div>
        </div>
      </main>
    );
  }

  const vendor = await resolveVendorForUser(userId, null);

  if (!vendor) {
    return (
      <main className="container-page py-10">
        <div className="rounded-2xl border border-white/10 bg-white/5 p-8">
          <h1 className="text-2xl font-semibold text-slate-50">Vendor not found</h1>
          <p className="mt-2 text-sm text-slate-200/70">
            We couldn’t resolve a vendor account for your login.
          </p>
          <div className="mt-6">
            <Link
              href="/vendor-portal"
              className="rounded-lg border border-white/10 bg-white/5 px-4 py-2 text-sm font-semibold text-slate-50 hover:bg-white/10"
            >
              Back to Vendor Portal
            </Link>
          </div>
        </div>
      </main>
    );
  }

  const RunModel: any = (prisma as any).assessmentRun ?? (prisma as any).assessment;

  if (!RunModel?.findMany) {
    return (
      <main className="container-page py-10">
        <div className="rounded-2xl border border-white/10 bg-white/5 p-8">
          <h1 className="text-2xl font-semibold text-slate-50">Assessments not available</h1>
          <p className="mt-2 text-sm text-slate-200/70">
            No <code className="text-slate-50">assessment</code> or <code className="text-slate-50">assessmentRun</code> model found.
          </p>
        </div>
      </main>
    );
  }

  const runs: any[] =
    (await RunModel.findMany({
      where: { vendorId: vendor.id },
      orderBy: [{ updatedAt: "desc" as any }, { id: "desc" as any }],
      take: 50,
      select: {
        id: true,
        title: true,
        status: true,
        startedAt: true,
        createdAt: true,
        updatedAt: true,
        templateId: true,
      },
    }).catch(() => [])) ?? [];

  // compute progress best-effort (answers + total questions)
  const rows = await Promise.all(
    runs.map(async (r) => {
      const runId = Number(r?.id);
      const answered = await getAnsweredCount(runId);
      const total = await getTotalQuestions(runId, r?.templateId ?? null);
      return { ...r, answered, total };
    })
  );

  return (
    <main className="container-page py-10">
      <div className="mb-6 flex flex-col gap-2 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <div className="text-xs font-semibold tracking-wider text-emerald-200/90">VENDOR PORTAL</div>
          <h1 className="mt-2 text-3xl font-semibold tracking-tight text-slate-50">Assessments</h1>
          <p className="mt-1 text-sm text-slate-200/70">
            Vendor: <span className="font-semibold text-slate-50">{vendor.name}</span>
          </p>
        </div>

        <div className="flex flex-wrap gap-2">
          <Link
            href="/vendor-portal"
            className="rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm font-semibold text-slate-50 hover:bg-white/10"
          >
            Back to Vendor Portal
          </Link>
        </div>
      </div>

      <div className="rounded-2xl border border-white/10 bg-white/5 p-5">
        <div className="flex items-center justify-between">
          <div className="text-sm font-semibold text-slate-50">Your assessment runs</div>
          <div className="text-xs text-slate-200/60">{rows.length} total</div>
        </div>

        {rows.length === 0 ? (
          <div className="mt-6 text-sm text-slate-200/70">
            No assessments yet. (Run <code className="text-slate-50">npm run seed:demo-assessment</code> to generate one.)
          </div>
        ) : (
          <div className="mt-4 overflow-hidden rounded-xl border border-white/10">
            <div className="grid grid-cols-12 gap-0 border-b border-white/10 bg-black/20 px-4 py-3 text-xs font-semibold text-slate-200/70">
              <div className="col-span-6">Run</div>
              <div className="col-span-3">Progress</div>
              <div className="col-span-2">Status</div>
              <div className="col-span-1 text-right">ID</div>
            </div>

            <div className="divide-y divide-white/10">
              {rows.map((r) => {
                const runId = Number(r?.id);
                const title = r?.title ?? `Assessment #${runId}`;
                const updated = r?.updatedAt ?? r?.createdAt ?? null;
                const status = String(r?.status ?? "UNKNOWN");

                const answered = typeof r.answered === "number" ? r.answered : null;
                const total = typeof r.total === "number" ? r.total : null;

                const progressText =
                  answered == null
                    ? "—"
                    : total == null
                    ? `${answered} answered`
                    : `${answered}/${total} answered`;

                return (
                  <Link
                    key={runId}
                    href={`/vendor-portal/assessments/${runId}`}
                    className="grid grid-cols-12 items-center gap-0 px-4 py-4 hover:bg-white/5"
                  >
                    <div className="col-span-6 min-w-0">
                      <div className="truncate text-sm font-semibold text-slate-50">{title}</div>
                      <div className="mt-1 text-xs text-slate-200/60">Updated: {fmtDate(updated)}</div>
                    </div>

                    <div className="col-span-3 text-sm text-slate-200/80">{progressText}</div>

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

                    <div className="col-span-1 text-right text-sm font-semibold text-slate-200/80">
                      #{runId}
                    </div>
                  </Link>
                );
              })}
            </div>
          </div>
        )}
      </div>
    </main>
  );
}
