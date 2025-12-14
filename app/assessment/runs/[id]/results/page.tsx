// app/assessment/runs/[id]/results/page.tsx
import Link from "next/link";
import prisma from "@/lib/prisma";

type ParamsPromise = Promise<{ id: string }>;
type Props = { params: ParamsPromise };

function cleanTemplateName(name: string | null | undefined) {
  if (!name) return null;

  // Remove common dev prefixes like:
  // "Phase200 Baseline CAIQ-style" -> "CAIQ-style"
  // "PHASE 200 — Baseline: CAIQ" -> "Baseline: CAIQ" (then further cleaned)
  // "Phase 200 - Something" -> "Something"
  let s = String(name).trim();

  // Remove leading "Phase###", "Phase ###", "PHASE ###", optionally followed by punctuation/words like baseline.
  s = s.replace(/^phase\s*\d+\s*[-—:]\s*/i, "");
  s = s.replace(/^phase\s*\d+\s*/i, "");

  // Remove leading "baseline" label if it immediately follows a phase tag
  s = s.replace(/^baseline\s*[-—:]\s*/i, "");
  s = s.replace(/^baseline\s+/i, "");

  // Clean redundant whitespace
  s = s.replace(/\s{2,}/g, " ").trim();

  return s || null;
}

function displayAssessmentTitle(args: {
  vendorName: string;
  templateName?: string | null;
  assessmentTitle?: string | null;
}) {
  const { vendorName, templateName, assessmentTitle } = args;

  // Prefer explicit assessment.title if present (usually production),
  // otherwise fall back to cleaned template name.
  const cleanedTemplate = cleanTemplateName(templateName);

  if (assessmentTitle && assessmentTitle.trim()) return `${vendorName} — ${assessmentTitle.trim()}`;
  if (cleanedTemplate) return `${vendorName} — ${cleanedTemplate}`;
  return `${vendorName} — Assessment Results`;
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
      vendor: { select: { id: true, name: true } },
      template: { select: { id: true, name: true, standard: true } },
      answers: { select: { id: true } },
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

  const answeredCount = assessment.answers?.length ?? 0;

  return (
    <main className="container-page py-10">
      <div className="mb-6">
        <div className="text-xs text-slate-400">
          Results • Run #{assessment.id} •{" "}
          <span className="text-emerald-300">{assessment.vendor?.name ?? "Vendor"}</span>
        </div>

        <div className="mt-2 flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
          <div>
            <h1 className="text-3xl md:text-4xl font-semibold tracking-tight text-slate-50">
              {title}
            </h1>
            <div className="mt-3 flex flex-wrap gap-2 text-xs">
              <span className="rounded-full border border-slate-800 bg-slate-950/60 px-3 py-1 text-slate-200">
                Status: <span className="font-semibold">{assessment.status}</span>
              </span>
              <span className="rounded-full border border-slate-800 bg-slate-950/60 px-3 py-1 text-slate-200">
                Answered: <span className="font-semibold">{answeredCount}</span>
              </span>
              {assessment.template?.standard ? (
                <span className="rounded-full border border-slate-800 bg-slate-950/60 px-3 py-1 text-slate-200">
                  {assessment.template.standard}
                </span>
              ) : null}
            </div>
          </div>

          <div className="flex items-center gap-2">
            <Link
              href={`/assessment/runs/${assessment.id}`}
              className="rounded-full border border-slate-800 bg-slate-950/60 px-4 py-2 text-sm font-semibold text-slate-100 hover:bg-slate-900"
            >
              Back to Run
            </Link>

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
      <section className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="rounded-3xl border border-slate-800 bg-slate-950/60 p-5">
          <div className="text-xs uppercase tracking-wider text-slate-400">Overall</div>
          <div className="mt-3 text-3xl font-semibold text-slate-50">
            {assessment.score ?? "—"}
          </div>
          <div className="mt-2 text-xs text-slate-500">Based on scoring engine + answered controls.</div>
        </div>

        <div className="rounded-3xl border border-slate-800 bg-slate-950/60 p-5">
          <div className="text-xs uppercase tracking-wider text-slate-400">Confidentiality</div>
          <div className="mt-3 text-3xl font-semibold text-slate-50">
            {assessment.confidentialityScore ?? "—"}
          </div>
        </div>

        <div className="rounded-3xl border border-slate-800 bg-slate-950/60 p-5">
          <div className="text-xs uppercase tracking-wider text-slate-400">Integrity</div>
          <div className="mt-3 text-3xl font-semibold text-slate-50">
            {assessment.integrityScore ?? "—"}
          </div>
        </div>

        <div className="rounded-3xl border border-slate-800 bg-slate-950/60 p-5 md:col-span-3">
          <div className="text-xs uppercase tracking-wider text-slate-400">Availability</div>
          <div className="mt-3 text-3xl font-semibold text-slate-50">
            {assessment.availabilityScore ?? "—"}
          </div>
        </div>
      </section>

      <section className="mt-6 rounded-3xl border border-slate-800 bg-slate-950/60 p-5">
        <div className="text-xs uppercase tracking-wider text-slate-400">Next steps</div>
        <ul className="mt-3 list-disc pl-5 text-sm text-slate-200 space-y-1">
          <li>
            Review auto-generated findings in{" "}
            <Link className="text-emerald-300 underline" href={`/vendors/${assessment.vendor?.id}#findings`}>
              Vendor Findings
            </Link>
            .
          </li>
          <li>Reopen the run if you need to edit answers and re-submit.</li>
        </ul>
      </section>
    </main>
  );
}
