// app/assessment/runs/[id]/page.tsx
import Link from "next/link";
import prisma from "@/lib/prisma";
import AssessmentRunEditor from "@/components/assessment-run-editor";
import { auth, currentUser } from "@clerk/nextjs/server";

export const runtime = "nodejs";

type ParamsPromise = Promise<{ id: string }>;

type Props = {
  params: ParamsPromise;
  searchParams?: Promise<{ as?: string }>;
};

function isInternalRouteBackHref() {
  // You’ve standardized on /assessment (list) now, but keep fallback.
  return "/assessment";
}

export default async function AssessmentRunPage({ params, searchParams }: Props) {
  const { userId } = auth();
  const user = userId ? await currentUser() : null;

  const { id } = await params;
  const runId = Number(id);

  const sp = searchParams ? await searchParams : {};
  const asVendorPreview = sp?.as === "vendor"; // internal "view as vendor" mode
  const backHref = isInternalRouteBackHref();

  if (!Number.isFinite(runId)) {
    return (
      <main className="container-page py-12">
        <h1 className="text-2xl font-semibold">Invalid assessment id</h1>
        <Link className="mt-4 inline-block underline" href={backHref}>
          Back to runs
        </Link>
      </main>
    );
  }

  const assessment = await prisma.assessment.findUnique({
    where: { id: runId },
    include: {
      vendor: { select: { id: true, name: true } },
      template: { select: { id: true, name: true } },
      answers: {
        select: {
          id: true,
          assessmentId: true,
          questionId: true,
          value: true,
          valueJson: true,
          updatedAt: true,
        },
      },
    },
  });

  if (!assessment) {
    return (
      <main className="container-page py-12">
        <h1 className="text-2xl font-semibold">Assessment not found</h1>
        <Link className="mt-4 inline-block underline" href={backHref}>
          Back to runs
        </Link>
      </main>
    );
  }

  /**
   * ✅ Enterprise access rules:
   * - Vendor users can only open runs where assessment.vendorId === user.publicMetadata.vendorId
   * - Internal users can open any run
   * - "as=vendor" preview is allowed (it only affects UI; still requires internal access)
   *
   * Since you haven’t wired internal org roles yet, we define:
   * - If user has publicMetadata.vendorId => treat as Vendor user (restricted)
   * - Otherwise treat as Internal user (unrestricted)
   */
  const userVendorIdRaw = (user?.publicMetadata as any)?.vendorId;
  const userVendorId =
    typeof userVendorIdRaw === "number"
      ? userVendorIdRaw
      : typeof userVendorIdRaw === "string"
      ? Number(userVendorIdRaw)
      : undefined;

  const isVendorUser = Number.isFinite(userVendorId as any);
  const isInternalUser = !!userId && !isVendorUser;

  // If not signed in, block (you can loosen later for demo)
  if (!userId) {
    return (
      <main className="container-page py-12">
        <h1 className="text-2xl font-semibold">Sign in required</h1>
        <p className="mt-2 text-slate-300">
          Please sign in to view this assessment run.
        </p>
        <Link className="mt-4 inline-block underline" href="/">
          Back home
        </Link>
      </main>
    );
  }

  // Vendor user restriction
  if (isVendorUser) {
    const runVendorId = (assessment as any).vendorId as number | null | undefined;

    if (!runVendorId || runVendorId !== userVendorId) {
      return (
        <main className="container-page py-12">
          <h1 className="text-2xl font-semibold">Access denied</h1>
          <p className="mt-2 text-slate-300">
            This assessment run isn’t assigned to your vendor account.
          </p>
          <Link className="mt-4 inline-block underline" href="/vendor-portal">
            Go to Vendor Portal
          </Link>
        </main>
      );
    }
  }

  // Internal user can access everything; preview flag just tweaks UI.
  const showInternalLinks = isInternalUser && !asVendorPreview;

  // Load questions:
  // Prefer template questions; fall back to answered questions only.
  let questions: any[] = [];
  if (assessment.templateId) {
    try {
      questions = await prisma.assessmentQuestion.findMany({
        where: { templateId: assessment.templateId },
        orderBy: [
          { sectionId: "asc" as any },
          { orderIndex: "asc" as any },
          { id: "asc" as any },
        ],
        include: { section: true },
      });
    } catch {
      questions = [];
    }
  }

  if (questions.length === 0) {
    // fallback: derive minimal question objects from answers
    questions = assessment.answers
      .filter((a) => a.questionId != null)
      .map((a) => ({
        id: a.questionId!,
        text: `Question #${a.questionId}`,
        type: "TEXT",
        required: false,
      }));
  }

  const initialAnswers = assessment.answers.map((a) => ({
    id: a.id,
    assessmentId: a.assessmentId,
    questionId: a.questionId,
    value: a.valueJson ?? a.value, // editor expects raw-ish value
    updatedAt: a.updatedAt ? a.updatedAt.toISOString() : null,
  }));

  // Back destinations depend on audience
  const effectiveBackHref = isVendorUser ? "/vendor-portal" : backHref;

  return (
    <main className="relative max-w-6xl mx-auto px-4 lg:px-6 py-12 lg:py-16">
      <div className="pointer-events-none absolute inset-x-0 -top-32 -z-10 h-64 bg-[radial-gradient(circle_at_top,_rgba(45,212,191,0.18),transparent_60%)]" />
      <div className="pointer-events-none absolute inset-x-0 bottom-0 -z-10 h-64 bg-[radial-gradient(circle_at_bottom,_rgba(56,189,248,0.14),transparent_60%)]" />

      <div className="flex items-start justify-between gap-4 mb-6">
        <div>
          <div className="text-xs tracking-[0.25em] text-emerald-200/80">
            {isVendorUser || asVendorPreview ? "VENDOR PORTAL" : "ASSESSMENTS"}
          </div>

          <h1 className="text-3xl font-semibold tracking-tight text-slate-50">
            Assessment Run
          </h1>

          {(asVendorPreview && isInternalUser) && (
            <div className="mt-3 rounded-2xl border border-emerald-500/20 bg-emerald-500/5 px-4 py-3 text-sm text-emerald-100">
              You’re viewing this run in <span className="font-semibold">Vendor-safe preview</span>{" "}
              mode (internal-only navigation hidden).
            </div>
          )}

          <div className="mt-2 text-sm text-slate-300">
            <span className="text-slate-400">Assessment ID:</span>{" "}
            <span className="font-semibold text-slate-100">{assessment.id}</span>
          </div>

          <div className="mt-2 flex flex-wrap gap-3 text-sm text-slate-300">
            {assessment.vendor ? (
              <span>
                <span className="text-slate-400">Vendor:</span>{" "}
                {showInternalLinks ? (
                  <Link
                    className="text-emerald-200 hover:underline"
                    href={`/vendors/${assessment.vendor.id}`}
                  >
                    {assessment.vendor.name}
                  </Link>
                ) : (
                  <span className="font-semibold text-slate-100">
                    {assessment.vendor.name}
                  </span>
                )}
              </span>
            ) : null}

            <span>
              <span className="text-slate-400">Status:</span>{" "}
              <span className="font-semibold text-slate-100">
                {assessment.status}
              </span>
            </span>

            <span>
              <span className="text-slate-400">Template:</span>{" "}
              <span className="font-semibold text-slate-100">
                {assessment.template?.name
                  ? assessment.template.name
                  : `#${assessment.templateId ?? "—"}`}
              </span>
            </span>
          </div>
        </div>

        <div className="flex flex-col items-end gap-2">
          <Link
            className="text-sm text-emerald-200 hover:underline"
            href={effectiveBackHref}
          >
            Back
          </Link>

          {/* Internal-only quick toggle to preview vendor-safe mode */}
          {isInternalUser && (
            <div className="flex items-center gap-2">
              {!asVendorPreview ? (
                <Link
                  href={`/assessment/runs/${assessment.id}?as=vendor`}
                  className="text-xs rounded-full border border-white/10 bg-white/5 px-3 py-1.5 text-slate-100 hover:bg-white/10"
                >
                  View as Vendor
                </Link>
              ) : (
                <Link
                  href={`/assessment/runs/${assessment.id}`}
                  className="text-xs rounded-full border border-emerald-500/25 bg-emerald-500/10 px-3 py-1.5 text-emerald-100 hover:bg-emerald-500/15"
                >
                  Back to Internal View
                </Link>
              )}
            </div>
          )}
        </div>
      </div>

      <AssessmentRunEditor
        assessmentId={assessment.id}
        initialStatus={assessment.status as any}
        questions={questions as any}
        initialAnswers={initialAnswers}
        backHref={effectiveBackHref}
      />
    </main>
  );
}
