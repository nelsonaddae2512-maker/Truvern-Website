// app/vendor-portal/assessments/[id]/page.tsx
import Link from "next/link";
import prisma from "@/lib/prisma";
import { auth } from "@clerk/nextjs/server";
import VendorAssessmentRunClient from "@/components/vendor-assessment-run-client";

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

function qOrder(q: any) {
  const oi = Number(q?.orderIndex);
  if (Number.isFinite(oi)) return oi;
  const o = Number(q?.order);
  if (Number.isFinite(o)) return o;
  return 9999;
}

async function resolveVendorForUser(userId: string, email?: string | null) {
  const anyPrisma: any = prisma;

  // Prefer explicit mappings if your schema has them
  if (typeof anyPrisma.vendorUser?.findFirst === "function") {
    const vu = await anyPrisma.vendorUser.findFirst({
      where: { userId },
      include: { vendor: { select: { id: true, name: true } } },
    }).catch(() => null);
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

  // Last resort: first vendor (dev-only safety net)
  return prisma.vendor.findFirst({ orderBy: { id: "asc" }, select: { id: true, name: true } }).catch(() => null);
}

export default async function VendorPortalAssessmentRunPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const runId = Number(id);

  const { userId } = auth();

  if (!userId) {
    return (
      <main className="container-page py-10">
        <div className="rounded-2xl border border-white/10 bg-white/5 p-8">
          <h1 className="text-2xl font-semibold text-slate-50">Vendor assessment</h1>
          <p className="mt-2 text-sm text-slate-200/70">Please sign in to access vendor assessments.</p>
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

  if (!Number.isFinite(runId)) {
    return (
      <main className="container-page py-10">
        <h1 className="text-2xl font-semibold text-slate-50">Invalid assessment id</h1>
      </main>
    );
  }

  // Support either prisma.assessment or prisma.assessmentRun
  const RunModel: any = (prisma as any).assessmentRun ?? (prisma as any).assessment;

  const run = RunModel
    ? await RunModel.findUnique({
        where: { id: runId },
        include: { vendor: { select: { id: true, name: true } } },
      }).catch(() => null)
    : null;

  if (!RunModel) {
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

  if (!run) {
    return (
      <main className="container-page py-10">
        <div className="rounded-2xl border border-white/10 bg-white/5 p-8">
          <h1 className="text-2xl font-semibold text-slate-50">Assessment not found</h1>
          <p className="mt-2 text-sm text-slate-200/70">No assessment run exists with id #{runId}.</p>
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

  // Resolve vendor for the logged-in user (best-effort)
  const vendor = await resolveVendorForUser(userId, null);

  // Enforce vendor ownership
  const runVendorId = Number((run as any)?.vendorId ?? run?.vendor?.id);
  if (!vendor || !Number.isFinite(runVendorId) || vendor.id !== runVendorId) {
    return (
      <main className="container-page py-10">
        <div className="rounded-2xl border border-white/10 bg-white/5 p-8">
          <h1 className="text-2xl font-semibold text-slate-50">Access denied</h1>
          <p className="mt-2 text-sm text-slate-200/70">
            This assessment does not belong to your vendor account.
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

  // Answers are run-scoped in your schema (assessmentId)
  const answers: any[] =
    (await (prisma as any).assessmentAnswer
      ?.findMany({
        where: { assessmentId: runId },
        select: { id: true, questionId: true, value: true, updatedAt: true },
      })
      .catch(() => [])) ?? [];

  // Questions: prefer run-scoped; fallback to template; fallback to any
  const AQ: any = (prisma as any).assessmentQuestion;
  const templateId = (run as any)?.templateId ?? null;

  let questions: any[] = [];
  if (AQ?.findMany) {
    questions =
      (await AQ.findMany({
        where: { assessmentId: runId },
        take: 1000,
      }).catch(() => [])) ?? [];

    if ((!questions || questions.length === 0) && templateId) {
      questions =
        (await AQ.findMany({
          where: { templateId },
          take: 1000,
        }).catch(() => [])) ?? [];
    }

    if (!questions || questions.length === 0) {
      questions =
        (await AQ.findMany({
          take: 200,
        }).catch(() => [])) ?? [];
    }
  }

  const sortedQuestions = [...questions].sort((a, b) => qOrder(a) - qOrder(b));

  return (
    <main className="container-page py-10">
      <div className="mb-6 flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
        <div>
          <div className="text-xs font-semibold tracking-wider text-emerald-200/90">VENDOR ASSESSMENT</div>
          <h1 className="mt-2 text-3xl font-semibold tracking-tight text-slate-50">
            {run?.title ?? `Assessment #${runId}`}
          </h1>

          <div className="mt-2 flex flex-wrap items-center gap-2 text-sm text-slate-200/70">
            <span
              className={clsx(
                "inline-flex items-center rounded-full border px-2.5 py-1 text-[11px] font-semibold",
                statusTone(String(run?.status ?? "UNKNOWN"))
              )}
            >
              {String(run?.status ?? "UNKNOWN")}
            </span>
            <span className="opacity-60">·</span>
            <span>Started: {fmtDate(run?.startedAt ?? run?.createdAt)}</span>
            <span className="opacity-60">·</span>
            <span>Updated: {fmtDate(run?.updatedAt ?? run?.createdAt)}</span>
          </div>

          <div className="mt-2 text-sm text-slate-200/70">
            Vendor: <span className="font-semibold text-slate-50">{vendor?.name ?? `Vendor #${vendor?.id ?? "—"}`}</span>
          </div>
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

      <VendorAssessmentRunClient
        assessmentId={runId}
        vendorId={vendor.id}
        questions={sortedQuestions as any}
        initialAnswers={answers as any}
      />
    </main>
  );
}
