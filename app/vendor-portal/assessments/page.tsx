// app/vendor-portal/assessments/page.tsx
import Link from "next/link";
import prisma from "@/lib/prisma";
import { auth, currentUser } from "@clerk/nextjs/server";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

function devBypassEnabled() {
  return (
    process.env.NODE_ENV !== "production" &&
    process.env.TRUVERN_DEV_BYPASS_AUTH === "1"
  );
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

function fmtDate(d?: Date | string | null) {
  if (!d) return "—";
  const dt = typeof d === "string" ? new Date(d) : d;
  return dt.toLocaleDateString(undefined, {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}

function normalizeStatus(s: any): string {
  const v = String(s ?? "").toUpperCase().trim();
  return v || "—";
}

function clamp(n: number, min: number, max: number) {
  return Math.max(min, Math.min(max, n));
}

export default async function VendorPortalAssessmentsPage({
  searchParams,
}: {
  searchParams?: Promise<Record<string, string | string[] | undefined>>;
}) {
  const sp = (await searchParams) ?? {};
  const statusParamRaw = Array.isArray(sp.status) ? sp.status[0] : sp.status;
  const statusFilter = statusParamRaw
    ? String(statusParamRaw).toUpperCase()
    : "ALL";

  const vendorId = await resolveVendorId();

  if (!vendorId) {
    return (
      <main className="container-page py-12">
        <h1 className="text-2xl font-semibold">Vendor Portal</h1>
        <p className="mt-2 text-slate-200/70">
          You must be signed in as a vendor to view assessments.
        </p>
        <div className="mt-6 flex gap-3">
          <Link className="btn btn-primary" href="/sign-in">
            Sign in
          </Link>
          <Link className="btn btn-secondary" href="/">
            Back home
          </Link>
        </div>
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
        <p className="mt-2 text-slate-200/70">
          Your account is not linked to a vendor record.
        </p>
      </main>
    );
  }

  const assessmentsRaw = await prisma.assessment.findMany({
    where: { vendorId: vendor.id } as any,
    orderBy: [{ updatedAt: "desc" as any }, { createdAt: "desc" as any }],
    take: 100,
    select: {
      id: true,
      status: true,
      createdAt: true,
      updatedAt: true,
      templateId: true,
      organizationId: true,
    } as any,
  });

  const assessments = assessmentsRaw.filter((a: any) => {
    if (statusFilter === "ALL") return true;
    return normalizeStatus(a.status) === statusFilter;
  });

  // -------- Progress data --------
  const assessmentIds = assessmentsRaw.map((a: any) => a.id);

  // Answered per assessment (AssessmentAnswer.value is String? in your schema)
  const answeredGroups =
    assessmentIds.length > 0
      ? await prisma.assessmentAnswer.groupBy({
          by: ["assessmentId"],
          where: {
            assessmentId: { in: assessmentIds },
            value: { not: null, notIn: [""] },
          } as any,
          _count: { _all: true },
        })
      : [];

  const answeredByAssessment = new Map<number, number>(
    (answeredGroups as any[]).map((g: any) => [
      g.assessmentId,
      g._count?._all ?? 0,
    ])
  );

  // Total questions per template (THIS matches your schema)
  const templateIds = Array.from(
    new Set(
      assessmentsRaw
        .map((a: any) => Number(a?.templateId))
        .filter((n) => Number.isFinite(n) && n > 0)
    )
  );

  const totalQuestionsByTemplate = new Map<number, number>();

  if (templateIds.length > 0) {
    const qGroups = await prisma.assessmentQuestion.groupBy({
      by: ["templateId"],
      where: { templateId: { in: templateIds } } as any,
      _count: { _all: true },
    });

    for (const g of qGroups as any[]) {
      const tid = Number(g.templateId);
      if (!Number.isFinite(tid)) continue;
      totalQuestionsByTemplate.set(tid, g._count?._all ?? 0);
    }

    // Optional fallback: if a template returned 0 (some datasets attach questions by sectionId only),
    // count via sections -> questions.sectionId
    const missing = templateIds.filter(
      (tid) => (totalQuestionsByTemplate.get(tid) ?? 0) === 0
    );

    if (missing.length > 0) {
      const sections = await prisma.assessmentSection.findMany({
        where: { templateId: { in: missing } } as any,
        select: { id: true, templateId: true },
      });

      const sectionIds = (sections as any[]).map((s: any) => s.id);

      if (sectionIds.length > 0) {
        const bySection = await prisma.assessmentQuestion.groupBy({
          by: ["sectionId"],
          where: { sectionId: { in: sectionIds } } as any,
          _count: { _all: true },
        });

        const sectionCount = new Map<number, number>(
          (bySection as any[]).map((g: any) => [
            Number(g.sectionId),
            g._count?._all ?? 0,
          ])
        );

        const rollup = new Map<number, number>();
        for (const s of sections as any[]) {
          const c = sectionCount.get(s.id) ?? 0;
          rollup.set(s.templateId, (rollup.get(s.templateId) ?? 0) + c);
        }

        for (const tid of missing) {
          const v = rollup.get(tid) ?? 0;
          if (v > 0) totalQuestionsByTemplate.set(tid, v);
        }
      }
    }
  }

  // Template metadata (naming only)
  const templates =
    templateIds.length > 0
      ? await prisma.assessmentTemplate.findMany({
          where: { id: { in: templateIds } },
          select: {
            id: true,
            name: true,
            description: true,
            standard: true,
            code: true,
            category: true,
            version: true,
            isActive: true,
          } as any,
        })
      : [];

  const templateById = new Map<number, any>(
    (templates as any[]).map((t: any) => [t.id, t])
  );

  // Status chips
  const statusCounts = assessmentsRaw.reduce(
    (acc: Record<string, number>, a: any) => {
      const k = normalizeStatus(a.status);
      acc[k] = (acc[k] ?? 0) + 1;
      return acc;
    },
    {}
  );

  const allCount = assessmentsRaw.length;

  const statusOptions = [
    { key: "ALL", label: `All (${allCount})` },
    ...Object.keys(statusCounts)
      .sort()
      .map((k) => ({
        key: k,
        label: `${k.replace(/_/g, " ")} (${statusCounts[k]})`,
      })),
  ];

  return (
    <main className="container-page py-10">
      <div className="flex items-start justify-between gap-4">
        <div>
          <h1 className="text-3xl font-semibold">Assessments</h1>
          <p className="mt-1 text-slate-200/70">
            For <span className="text-slate-100">{vendor.name}</span>
          </p>
        </div>
        <Link href="/vendor-portal" className="btn btn-secondary">
          Back to Vendor Portal
        </Link>
      </div>

      {/* Filters */}
      <div className="mt-5 flex flex-wrap items-center gap-2">
        {statusOptions.map((opt) => {
          const active = opt.key === statusFilter;
          const href =
            opt.key === "ALL"
              ? "/vendor-portal/assessments"
              : `/vendor-portal/assessments?status=${encodeURIComponent(
                  opt.key
                )}`;
          return (
            <Link
              key={opt.key}
              href={href}
              className={
                active
                  ? "rounded-full border border-emerald-400/40 bg-emerald-500/10 px-3 py-1 text-xs font-semibold text-emerald-200"
                  : "rounded-full border border-white/10 bg-white/5 px-3 py-1 text-xs font-semibold text-slate-200/80 hover:bg-white/10"
              }
            >
              {opt.label}
            </Link>
          );
        })}
      </div>

      <div className="mt-6 rounded-2xl border border-white/10 bg-white/[0.03] overflow-hidden">
        <div className="px-5 py-4 border-b border-white/10 flex items-center justify-between">
          <div className="text-sm font-semibold text-slate-50">
            Recent assessments
          </div>
          <div className="text-xs text-slate-200/60">
            {assessments.length} shown
          </div>
        </div>

        {assessments.length === 0 ? (
          <div className="px-5 py-6 text-sm text-slate-200/70">
            No assessments match this filter.
          </div>
        ) : (
          <div className="divide-y divide-white/5">
            {assessments.map((a: any) => {
              const rawTemplateId = Number(a?.templateId);
              const hasTemplateId =
                Number.isFinite(rawTemplateId) && rawTemplateId > 0;

              const t = hasTemplateId ? templateById.get(rawTemplateId) : null;

              const displayName = t?.name
                ? t.name
                : hasTemplateId
                ? `Template #${rawTemplateId}`
                : "Custom assessment";

              const sub =
                t?.standard || t?.code || t?.category
                  ? [t?.standard, t?.code, t?.category]
                      .filter(Boolean)
                      .join(" • ")
                  : null;

              const answered = answeredByAssessment.get(a.id) ?? 0;
              const total = hasTemplateId
                ? totalQuestionsByTemplate.get(rawTemplateId) ?? 0
                : 0;

              const pct =
                total > 0
                  ? clamp(Math.round((answered / total) * 100), 0, 100)
                  : 0;

              return (
                <div
                  key={a.id}
                  className="px-5 py-4 flex items-center justify-between gap-4"
                >
                  <div className="min-w-0 flex-1">
                    <div className="flex items-center gap-2 min-w-0">
                      <div className="text-sm font-semibold text-slate-50 truncate">
                        {displayName}
                      </div>
                      <span className="text-[11px] rounded-full border border-white/10 bg-white/5 px-2 py-0.5 text-slate-200/80">
                        {normalizeStatus(a.status)}
                      </span>
                    </div>

                    <div className="mt-1 text-xs text-slate-200/60">
                      {sub ? <span>{sub} • </span> : null}
                      Updated {fmtDate(a.updatedAt)} • Created{" "}
                      {fmtDate(a.createdAt)}
                    </div>

                    {/* Progress */}
                    <div className="mt-2">
                      <div className="flex items-center justify-between text-[11px] text-slate-200/70">
                        <span>
                          {total > 0
                            ? `${answered}/${total} answered`
                            : "Progress: —"}
                        </span>
                        <span>{total > 0 ? `${pct}%` : ""}</span>
                      </div>
                      <div className="mt-1 h-2 w-full rounded-full bg-white/10 overflow-hidden">
                        <div
                          className="h-full rounded-full bg-emerald-500/70"
                          style={{ width: `${pct}%` }}
                        />
                      </div>
                    </div>
                  </div>

                  <div className="flex items-center gap-2">
                    <Link
                      href={`/assessment/runs/${a.id}`}
                      className="btn btn-primary"
                    >
                      Open
                    </Link>
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
