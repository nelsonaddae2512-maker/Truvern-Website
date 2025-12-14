// app/assessment/[id]/page.tsx
import { notFound } from "next/navigation";
import prisma from "@/lib/prisma";
import Link from "next/link";

export const dynamic = "force-dynamic";

type PageProps = {
  params: Promise<{
    id: string;
  }>;
};

function formatDate(value: string | Date | null | undefined) {
  if (!value) return "—";
  const d = typeof value === "string" ? new Date(value) : value;
  if (Number.isNaN(d.getTime())) return "—";
  return d.toLocaleDateString(undefined, {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}

export default async function AssessmentBuilderPage({ params }: PageProps) {
  const { id } = await params;
  const assessmentId = Number(id);
  if (!assessmentId || Number.isNaN(assessmentId)) {
    notFound();
  }

  const raw = await prisma.assessment.findUnique({
    where: { id: assessmentId },
    include: {
      vendor: {
        select: {
          id: true,
          name: true,
        },
      },
    },
  });

  if (!raw) {
    notFound();
  }

  const assessment = raw as any;

  const vendorId: number | null = assessment.vendor?.id ?? null;
  const vendorName: string = assessment.vendor?.name ?? "Unknown vendor";

  const title: string =
    assessment.title ??
    assessment.name ??
    `Assessment #${assessment.id}`;

  const status: string =
    assessment.status ??
    assessment.state ??
    "Draft";

  const createdAt = assessment.createdAt;
  const updatedAt =
    assessment.updatedAt ??
    assessment.lastUpdatedAt ??
    assessment.createdAt;

  const vendorHref =
    vendorId != null ? `/vendors/${vendorId}?view=workspace` : "/vendors";

  // If the assessment object happens to have a questions array, we can show a count
  const questions = Array.isArray(assessment.questions)
    ? assessment.questions
    : [];
  const questionCount = questions.length;

  return (
    <main className="min-h-screen bg-slate-950 text-slate-50">
      <div className="mx-auto flex max-w-5xl flex-col gap-8 px-4 pb-24 pt-10 lg:pt-12">
        {/* Header */}
        <header className="space-y-3">
          <div className="flex items-center justify-between gap-3">
            <div>
              <p className="text-xs font-semibold tracking-[0.22em] text-emerald-300">
                ASSESSMENT BUILDER
              </p>
              <h1 className="mt-2 text-3xl font-semibold tracking-tight md:text-4xl">
                {title}
              </h1>
              <p className="mt-2 max-w-2xl text-sm text-slate-300">
                Builder view for this assessment. Use this page to review how the
                questionnaire is structured, track status, and jump into the
                vendor workspace when you&apos;re ready to update evidence or
                remediation.
              </p>
            </div>
            <div className="hidden flex-col items-end text-right text-[11px] text-slate-400 md:flex">
              <span>Created {formatDate(createdAt)}</span>
              <span>Last updated {formatDate(updatedAt)}</span>
            </div>
          </div>
        </header>

        {/* Main grid */}
        <section className="grid gap-6 md:grid-cols-[minmax(0,1.7fr)_minmax(0,1.3fr)]">
          {/* Left: core builder info */}
          <div className="space-y-5">
            {/* Summary card */}
            <div className="rounded-2xl border border-slate-800 bg-slate-900/60 p-5 text-sm text-slate-200">
              <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
                <div>
                  <p className="text-xs font-semibold uppercase tracking-[0.18em] text-slate-400">
                    Assessment overview
                  </p>
                  <p className="mt-1 text-xs text-slate-400">
                    Vendor, status, and high-level stats for this assessment.
                  </p>
                </div>
                <div className="flex flex-wrap items-center justify-end gap-2 text-xs">
                  <span className="rounded-full border border-slate-700 bg-slate-950/80 px-2 py-[3px] text-[11px] text-slate-300">
                    Status:{" "}
                    <span className="font-semibold text-emerald-300">
                      {status}
                    </span>
                  </span>
                  <Link
                    href={vendorHref}
                    className="rounded-full border border-slate-700 bg-slate-950/80 px-3 py-1.5 text-[11px] font-medium text-slate-100 hover:border-emerald-400/70 hover:bg-slate-900"
                  >
                    Open vendor workspace
                  </Link>
                </div>
              </div>

              <div className="mt-4 grid gap-3 text-xs text-slate-200 sm:grid-cols-3">
                <div className="rounded-xl border border-slate-800 bg-slate-950/80 px-3 py-2.5">
                  <p className="text-[11px] text-slate-400">Vendor</p>
                  <Link
                    href={vendorHref}
                    className="mt-1 block text-[11px] font-medium text-emerald-300 hover:text-emerald-200"
                  >
                    {vendorName}
                  </Link>
                </div>

                <div className="rounded-xl border border-slate-800 bg-slate-950/80 px-3 py-2.5">
                  <p className="text-[11px] text-slate-400">Questions</p>
                  <p className="mt-1 text-sm font-semibold text-slate-50">
                    {questionCount || "—"}
                  </p>
                  <p className="text-[11px] text-slate-500">
                    Total questions in this builder
                  </p>
                </div>

                <div className="rounded-xl border border-slate-800 bg-slate-950/80 px-3 py-2.5">
                  <p className="text-[11px] text-slate-400">Timeline</p>
                  <p className="mt-1 text-[11px] text-slate-200">
                    Created {formatDate(createdAt)}
                  </p>
                  <p className="text-[11px] text-slate-500">
                    Updated {formatDate(updatedAt)}
                  </p>
                </div>
              </div>
            </div>

            {/* Builder layout placeholder */}
            <div className="rounded-2xl border border-slate-800 bg-slate-900/60 p-5 text-sm text-slate-200">
              <h2 className="text-sm font-semibold tracking-tight">
                Sections &amp; questions
              </h2>
              <p className="mt-2 text-xs text-slate-400">
                This is a lightweight builder view. In a future phase, this area can
                show sections, question groups, and per-question mappings to
                evidence. For now, use the vendor workspace to edit full
                questionnaires, and keep this screen as a clean summary for
                reviews and board preparation.
              </p>

              <div className="mt-4 grid gap-3 rounded-xl border border-dashed border-slate-700 bg-slate-950/60 p-4 text-xs text-slate-400">
                <p className="font-medium text-slate-300">
                  Placeholder — Assessment structure
                </p>
                <p>
                  When you&apos;re ready, we can extend this builder to render real
                  sections and questions from your schema (for example:
                  <span className="text-slate-200">
                    {" "}
                    &quot;General security&quot;, &quot;Access management&quot;,
                    &quot;Incident response&quot;
                  </span>{" "}
                  etc.).
                </p>
              </div>
            </div>
          </div>

          {/* Right: guidance + meta */}
          <aside className="space-y-4 text-xs text-slate-200">
            <div className="rounded-2xl border border-slate-800 bg-slate-900/70 p-5">
              <p className="text-[11px] font-semibold uppercase tracking-[0.18em] text-slate-400">
                How to use this view
              </p>
              <p className="mt-2 text-slate-300">
                Treat this screen as the &quot;overview pane&quot; for this
                assessment. It works well for:
              </p>
              <ul className="mt-2 list-disc space-y-1 pl-4 text-slate-300">
                <li>Checking which vendor the assessment belongs to.</li>
                <li>Confirming the status and last updated date.</li>
                <li>Jumping into the vendor workspace to update answers.</li>
              </ul>
            </div>

            <div className="rounded-2xl border border-slate-800 bg-slate-900/70 p-5">
              <p className="text-[11px] font-semibold uppercase tracking-[0.18em] text-slate-400">
                For board &amp; customer reporting
              </p>
              <p className="mt-2 text-slate-300">
                When preparing board reports or answering customer questionnaires,
                pair this builder view with:
              </p>
              <ul className="mt-2 list-disc space-y-1 pl-4 text-slate-300">
                <li>
                  The <span className="font-medium">Board Report</span> route for
                  portfolio views.
                </li>
                <li>
                  The <span className="font-medium">Trust Network</span> for
                  shareable public profiles.
                </li>
                <li>
                  The vendor workspace for detailed remediation plans and evidence.
                </li>
              </ul>
            </div>

            <div className="rounded-2xl border border-slate-800 bg-slate-900/70 p-4 text-[11px] text-slate-400">
              <p>
                This builder page is intentionally lightweight: it surfaces key
                metadata without exposing sensitive remediation details. It&apos;s
                safe to reference in internal docs and board packs.
              </p>
            </div>
          </aside>
        </section>

        {/* Footer link back */}
        <div className="mt-2 text-xs text-slate-500">
          <Link
            href="/assessment"
            className="text-emerald-300 hover:text-emerald-200"
          >
            ← Back to all assessments
          </Link>
        </div>
      </div>
    </main>
  );
}
