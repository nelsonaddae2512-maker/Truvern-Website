// app/assessment/runs/[id]/page.tsx
import Link from "next/link";
import prisma from "@/lib/prisma";
import { SignedIn, SignedOut } from "@clerk/nextjs";
import AssessmentRunResponder from "@/components/assessment-run-responder";

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
  return dt.toLocaleDateString(undefined, {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}

function statusTone(status: string) {
  const s = String(status || "").toUpperCase();
  if (s.includes("IN_PROGRESS"))
    return "border-sky-500/30 bg-sky-500/10 text-sky-200";
  if (s.includes("COMPLETE") || s.includes("DONE"))
    return "border-emerald-500/30 bg-emerald-500/10 text-emerald-200";
  if (s.includes("CANCEL") || s.includes("ARCHIVE"))
    return "border-slate-500/30 bg-slate-500/10 text-slate-200";
  return "border-white/10 bg-white/5 text-slate-200/80";
}

function qOrder(q: any) {
  const oi = Number(q?.orderIndex);
  if (Number.isFinite(oi)) return oi;
  const o = Number(q?.order);
  if (Number.isFinite(o)) return o;
  return 9999;
}

export default async function AssessmentRunPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const runId = Number(id);

  if (!Number.isFinite(runId)) {
    return (
      <main className="container-page py-10">
        <h1 className="text-2xl font-semibold text-slate-50">Invalid run id</h1>
      </main>
    );
  }

  // Support either prisma.assessment or prisma.assessmentRun
  const RunModel: any =
    (prisma as any).assessmentRun ?? (prisma as any).assessment;

  const run = RunModel
    ? await RunModel.findUnique({
        where: { id: runId },
        include: {
          vendor: { select: { id: true, name: true, riskScore: true } },
        },
      }).catch(() => null)
    : null;

  // Answers are run-scoped in your schema (assessmentId)
  const answers: any[] =
    (await (prisma as any).assessmentAnswer
      ?.findMany({
        where: { assessmentId: runId },
        select: { id: true, questionId: true, value: true, updatedAt: true },
      })
      .catch(() => [])) ?? [];

  const answerMap = new Map<number, any>();
  for (const a of answers) {
    const qid = Number(a?.questionId);
    if (Number.isFinite(qid)) answerMap.set(qid, a);
  }

  // Questions may be template-scoped in your schema.
  const templateId = (run as any)?.templateId ?? null;

  // Prefer: run-scoped questions (assessmentId) if your schema supports it.
  // Fallback: template-scoped questions (templateId).
  // Final fallback: show some questions anyway (to avoid empty run views).
  let questions: any[] = [];
  const AQ: any = (prisma as any).assessmentQuestion;

  if (AQ?.findMany) {
    // 1) Try run-scoped
    questions =
      (await AQ.findMany({
        where: { assessmentId: runId },
        take: 1000,
      }).catch(() => [])) ?? [];

    // 2) Try template-scoped
    if ((!questions || questions.length === 0) && templateId) {
      questions =
        (await AQ.findMany({
          where: { templateId },
          take: 1000,
        }).catch(() => [])) ?? [];
    }

    // 3) Try all questions (last resort)
    if (!questions || questions.length === 0) {
      questions =
        (await AQ.findMany({
          take: 200,
        }).catch(() => [])) ?? [];
    }
  }

  const sortedQuestions = [...questions].sort((a, b) => qOrder(a) - qOrder(b));
  const answeredCount = sortedQuestions.filter((q) =>
    answerMap.has(Number(q?.id))
  ).length;

  return (
    <main className="container-page py-10">
      <SignedOut>
        <div className="rounded-2xl border border-white/10 bg-white/5 p-8">
          <h1 className="text-2xl font-semibold text-slate-50">Assessment run</h1>
          <p className="mt-2 text-sm text-slate-200/70">
            Please sign in to view this run.
          </p>
          <div className="mt-6 flex gap-2">
            <Link
              href="/sign-in"
              className="rounded-lg border border-white/10 bg-white/5 px-4 py-2 text-sm font-semibold text-slate-50 hover:bg-white/10"
            >
              Sign in
            </Link>
            <Link
              href="/assessment"
              className="rounded-lg border border-white/10 bg-white/5 px-4 py-2 text-sm font-semibold text-slate-50 hover:bg-white/10"
            >
              Back to assessments
            </Link>
          </div>
        </div>
      </SignedOut>

      <SignedIn>
        {!RunModel ? (
          <div className="rounded-2xl border border-white/10 bg-white/5 p-8">
            <h1 className="text-2xl font-semibold text-slate-50">
              Assessments not available
            </h1>
            <p className="mt-2 text-sm text-slate-200/70">
              No <code className="text-slate-50">assessment</code> or{" "}
              <code className="text-slate-50">assessmentRun</code> model found
              in Prisma.
            </p>
          </div>
        ) : !run ? (
          <div className="rounded-2xl border border-white/10 bg-white/5 p-8">
            <h1 className="text-2xl font-semibold text-slate-50">Run not found</h1>
            <p className="mt-2 text-sm text-slate-200/70">
              No assessment run exists with id #{runId}.
            </p>
            <div className="mt-6">
              <Link
                href="/assessment"
                className="rounded-lg border border-white/10 bg-white/5 px-4 py-2 text-sm font-semibold text-slate-50 hover:bg-white/10"
              >
                Back to assessments
              </Link>
            </div>
          </div>
        ) : (
          <>
            <div className="mb-6 flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
              <div>
                <div className="text-xs font-semibold tracking-wider text-emerald-200/90">
                  ASSESSMENT RUN
                </div>
                <h1 className="mt-2 text-3xl font-semibold tracking-tight text-slate-50">
                  {run?.title ?? `Run #${run.id}`}
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
                  Vendor:{" "}
                  {run?.vendor?.id ? (
                    <Link
                      href={`/vendors/${run.vendor.id}`}
                      className="font-semibold text-emerald-200/90 hover:text-emerald-200"
                    >
                      {run.vendor.name ?? `Vendor #${run.vendor.id}`}
                    </Link>
                  ) : (
                    <span className="opacity-70">—</span>
                  )}
                </div>

                <div className="mt-2 text-sm text-slate-200/70">
                  Progress:{" "}
                  <span className="font-semibold text-slate-50">
                    {answeredCount}/{sortedQuestions.length}
                  </span>{" "}
                  answered
                </div>
              </div>

              <div className="flex flex-wrap gap-2">
                <Link
                  href="/assessment"
                  className="rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm font-semibold text-slate-50 hover:bg-white/10"
                >
                  Back to assessments
                </Link>
                {run?.vendor?.id ? (
                  <Link
                    href={`/vendors/${run.vendor.id}`}
                    className="rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm font-semibold text-slate-50 hover:bg-white/10"
                  >
                    View vendor
                  </Link>
                ) : null}
              </div>
            </div>

            {/* ✅ Interactive responder UI (clickable answers + autosave + scoring) */}
            <AssessmentRunResponder
              assessmentId={run.id}
              questions={sortedQuestions as any}
              initialAnswers={answers as any}
            />

            <div className="mt-3 text-xs text-slate-200/50">
              Template: {templateId ? `#${templateId}` : "—"} · Answers:{" "}
              {answers.length}
            </div>
          </>
        )}
      </SignedIn>
    </main>
  );
}
