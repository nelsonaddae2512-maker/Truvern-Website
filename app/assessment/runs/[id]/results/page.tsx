// app/assessment/runs/[id]/results/page.tsx
import Link from "next/link";
import prisma from "@/lib/prisma";

type ParamsPromise = Promise<{ id: string }>;
type Props = { params: ParamsPromise };

function cleanTemplateName(name: string | null | undefined) {
  if (!name) return null;

  let s = String(name).trim();

  s = s.replace(/^phase\s*\d+\s*[-—:]\s*/i, "");
  s = s.replace(/^phase\s*\d+\s*/i, "");

  s = s.replace(/^baseline\s*[-—:]\s*/i, "");
  s = s.replace(/^baseline\s+/i, "");

  s = s.replace(/\s{2,}/g, " ").trim();

  return s || null;
}

function displayAssessmentTitle(args: {
  vendorName: string;
  templateName?: string | null;
  assessmentTitle?: string | null;
}) {
  const { vendorName, templateName, assessmentTitle } = args;

  const cleanedTemplate = cleanTemplateName(templateName);

  if (assessmentTitle && assessmentTitle.trim())
    return `${vendorName} — ${assessmentTitle.trim()}`;
  if (cleanedTemplate) return `${vendorName} — ${cleanedTemplate}`;
  return `${vendorName} — Assessment Results`;
}

function clamp(n: number, min: number, max: number) {
  return Math.max(min, Math.min(max, n));
}

function scoreTone(score: number | null | undefined) {
  if (score == null) return "border-slate-800 bg-slate-950/60 text-slate-200";
  if (score >= 85) return "border-emerald-500/30 bg-emerald-500/10 text-emerald-200";
  if (score >= 70) return "border-sky-500/30 bg-sky-500/10 text-sky-200";
  if (score >= 50) return "border-amber-500/30 bg-amber-500/10 text-amber-200";
  return "border-rose-500/30 bg-rose-500/10 text-rose-200";
}

function scoreLabel(score: number | null | undefined) {
  if (score == null) return "Unscored";
  if (score >= 85) return "Strong";
  if (score >= 70) return "Healthy";
  if (score >= 50) return "Watch";
  return "High Risk";
}

export default async function AssessmentResultsPage({ params }: Props) {
  const { id } = await params;
  const assessmentId = Number(id);

  if (!assessmentId || Number.isNaN(assessmentId)) {
    return (
      <main className="container-page py-16">
        <h1 className="text-2xl font-semibold tracking-tight">Invalid assessment id</h1>
        <p className="mt-3 text-sm text-slate-400">Return to Runs &amp; scores.</p>
        <Link className="mt-6 inline-block underline" href="/assessment/runs">
          Back to runs
        </Link>
      </main>
    );
  }

  const assessment = await prisma.assessment.findUnique({
    where: { id: assessmentId },
    select: {
      id: true,
      status: true,
      title: true,
      score: true,
      confidentialityScore: true,
      integrityScore: true,
      availabilityScore: true,
      vendorId: true,
      vendor: { select: { id: true, name: true } },
      template: { select: { id: true, name: true, standard: true } },

      // Use counts rather than pulling arrays
      _count: { select: { answers: true } },
    },
  });

  if (!assessment) {
    return (
      <main className="container-page py-16">
        <h1 className="text-2xl font-semibold tracking-tight">Run not found</h1>
        <p className="mt-3 text-sm text-slate-400">Return to Runs &amp; scores.</p>
        <Link className="mt-6 inline-block underline" href="/assessment/runs">
          Back to runs
        </Link>
      </main>
    );
  }

  const title = displayAssessmentTitle({
    vendorName: assessment.vendor?.name ?? "Vendor",
    templateName: assessment.template?.name ?? null,
    assessmentTitle: assessment.title ?? null,
  });

  const answeredCount = assessment._count?.answers ?? 0;

  const totalCount = assessment.template?.id
    ? await prisma.assessmentQuestion.count({
        where: { templateId: assessment.template.id },
      })
    : 0;

  const pct = totalCount > 0 ? Math.round((answeredCount / totalCount) * 100) : 0;
  const progressPct = clamp(pct, 0, 100);

  const vendorId = assessment.vendor?.id ?? assessment.vendorId;

  return (
    <main className="container-page py-10">
      <div className="mb-6">
        <div className="text-xs text-slate-400">
          Results • Run #{assessment.id} •{" "}
          <span className="text-emerald-300">{assessment.vendor?.name ?? "Vendor"}</span>
        </div>

        <div className="mt-2 flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
          <div className="min-w-0">
            <h1 className="text-3xl md:text-4xl font-semibold tracking-tight text-slate-50">
              {title}
            </h1>

            <div className="mt-3 flex flex-wrap items-center gap-2 text-xs">
              <span className="rounded-full border border-slate-800 bg-slate-950/60 px-3 py-1 text-slate-200">
                Status: <span className="font-semibold">{assessment.status}</span>
              </span>

              <span className="rounded-full border border-slate-800 bg-slate-950/60 px-3 py-1 text-slate-200">
                Answered:{" "}
                <span className="font-semibold">
                  {answeredCount}/{totalCount || "—"}
                </span>
              </span>

              <span className={`rounded-full border px-3 py-1 font-semibold ${scoreTone(assessment.score)}`}>
                {scoreLabel(assessment.score)}
                {assessment.score != null ? ` • ${assessment.score}` : ""}
              </span>

              {assessment.template?.standard ? (
                <span className="rounded-full border border-slate-800 bg-slate-950/60 px-3 py-1 text-slate-200">
                  {assessment.template.standard}
                </span>
              ) : null}
            </div>

            <div className="mt-4 max-w-xl">
              <div className="flex items-center justify-between text-[11px] text-slate-400">
                <span>Completion</span>
                <span className="font-semibold text-slate-200">{progressPct}%</span>
              </div>
              <div className="mt-2 h-2 rounded-full bg-slate-900 overflow-hidden border border-slate-800">
                <div className="h-full bg-emerald-500/70" style={{ width: `${progressPct}%` }} />
              </div>
              <div className="mt-2 text-[11px] text-slate-500">
                This score is refreshed at completion (Phase 323 baseline).
              </div>
            </div>
          </div>

          <div className="flex flex-wrap items-center gap-2">
            <Link
              href={`/assessment/runs/${assessment.id}`}
              className="rounded-full border border-slate-800 bg-slate-950/60 px-4 py-2 text-sm font-semibold text-slate-100 hover:bg-slate-900"
            >
              Back to Run
            </Link>

            {vendorId ? (
              <>
                <Link
                  href={`/vendors/${vendorId}`}
                  className="rounded-full border border-slate-800 bg-slate-950/60 px-4 py-2 text-sm font-semibold text-slate-100 hover:bg-slate-900"
                >
                  Vendor Workspace ↗
                </Link>

                <Link
                  href={`/vendors/${vendorId}/findings`}
                  className="rounded-full border border-amber-400/50 bg-amber-500/10 px-4 py-2 text-sm font-semibold text-amber-200 hover:bg-amber-500/15"
                >
                  Findings ↗
                </Link>

                <Link
                  href="/board-report"
                  className="rounded-full border border-emerald-400/60 bg-emerald-500/10 px-4 py-2 text-sm font-semibold text-emerald-200 hover:bg-emerald-500/15"
                >
                  Board Report ↗
                </Link>
              </>
            ) : null}

            <form action={`/api/assessment-runs/${assessment.id}/reopen`} method="post">
              <button
                type="submit"
                className="rounded-full border border-amber-400/50 bg-amber-500/10 px-4 py-2 text-sm font-semibold text-amber-200 hover:bg-amber-500/15"
              >
                Reopen
              </button>
            </form>
          </div>
        </div>
      </div>

      {/* Score cards */}
      <section className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="rounded-3xl border border-slate-800 bg-slate-950/60 p-5">
          <div className="text-xs uppercase tracking-wider text-slate-400">Overall</div>
          <div className="mt-3 text-3xl font-semibold text-slate-50">{assessment.score ?? "—"}</div>
          <div className="mt-2 text-xs text-slate-500">Baseline score at completion.</div>
        </div>

        <div className="rounded-3xl border border-slate-800 bg-slate-950/60 p-5">
          <div className="text-xs uppercase tracking-wider text-slate-400">Confidentiality</div>
          <div className="mt-3 text-3xl font-semibold text-slate-50">
            {assessment.confidentialityScore ?? "—"}
          </div>
          <div className="mt-2 text-xs text-slate-500">CIA rollup (baseline mirrors overall).</div>
        </div>

        <div className="rounded-3xl border border-slate-800 bg-slate-950/60 p-5">
          <div className="text-xs uppercase tracking-wider text-slate-400">Integrity</div>
          <div className="mt-3 text-3xl font-semibold text-slate-50">
            {assessment.integrityScore ?? "—"}
          </div>
          <div className="mt-2 text-xs text-slate-500">CIA rollup (baseline mirrors overall).</div>
        </div>

        <div className="rounded-3xl border border-slate-800 bg-slate-950/60 p-5">
          <div className="text-xs uppercase tracking-wider text-slate-400">Availability</div>
          <div className="mt-3 text-3xl font-semibold text-slate-50">
            {assessment.availabilityScore ?? "—"}
          </div>
          <div className="mt-2 text-xs text-slate-500">CIA rollup (baseline mirrors overall).</div>
        </div>
      </section>

      <section className="mt-6 rounded-3xl border border-slate-800 bg-slate-950/60 p-5">
        <div className="text-xs uppercase tracking-wider text-slate-400">Next steps</div>
        <ul className="mt-3 list-disc pl-5 text-sm text-slate-200 space-y-1">
          <li>
            Review findings in{" "}
            {vendorId ? (
              <Link className="text-emerald-300 underline" href={`/vendors/${vendorId}/findings`}>
                Vendor Findings
              </Link>
            ) : (
              <span className="text-slate-300">Vendor Findings</span>
            )}
            .
          </li>
          <li>Use Board Report for a board-ready snapshot.</li>
          <li>Reopen the run if you need to edit answers and re-submit.</li>
        </ul>
      </section>
    </main>
  );
}
