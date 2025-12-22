// app/assessment/runs/[id]/page.tsx

import Link from "next/link";
import prisma from "@/lib/prisma";
import { requireDbOrganization } from "@/lib/org-db";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

function parseId(raw: unknown): number | null {
  const v = Array.isArray(raw) ? raw[0] : raw;
  const s = typeof v === "string" ? v.trim() : String(v ?? "").trim();
  const n = Number(s);
  return Number.isFinite(n) ? n : null;
}

export default async function AssessmentRunPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const ctx: any = await requireDbOrganization();

  // If org isn't selected/available, do NOT query prisma (prevents organizationId: undefined)
  if (!ctx || typeof ctx.id !== "number") {
    return (
      <main className="container-page py-10">
        <h1 className="text-2xl font-semibold text-white">
          Select an organization to view runs
        </h1>
        <p className="mt-2 text-white/70">
          Your session is signed in, but no organization context is active.
        </p>
        <div className="mt-6 flex flex-wrap gap-3">
          <Link className="btn-primary" href="/select-org">
            Choose organization
          </Link>
          <Link className="btn-glass" href="/assessment">
            Back to assessments
          </Link>
        </div>
      </main>
    );
  }

  const orgId = ctx.id;

  const { id } = await params;
  const runId = parseId(id);

  if (!runId) {
    return (
      <main className="container-page py-10">
        <h1 className="text-2xl font-semibold text-white">Invalid run id</h1>
        <Link
          href="/assessment"
          className="mt-4 inline-block text-sky-300 hover:underline"
        >
          ← Back to assessments
        </Link>
      </main>
    );
  }

  let run: any = null;
  let underlyingError: string | null = null;

  try {
    run = await (prisma as any).assessmentRun.findFirst({
      where: { id: runId, organizationId: orgId },
      include: {
        vendor: { select: { id: true, name: true } },
        // IMPORTANT: Assessment model does NOT have `name` — it has `title`
        assessment: { select: { id: true, title: true, status: true } },
      },
    });
  } catch (e: any) {
    underlyingError = e?.message || String(e);
  }

  if (!run) {
    return (
      <main className="container-page py-10">
        <h1 className="text-2xl font-semibold text-white">
          Assessment run not found
        </h1>

        {underlyingError ? (
          <p className="mt-3 text-white/70">
            Underlying query error:{" "}
            <span className="text-white/80">{underlyingError}</span>
          </p>
        ) : (
          <p className="mt-3 text-white/70">
            This run may not exist or may not belong to your organization.
          </p>
        )}

        <Link
          href="/assessment"
          className="mt-6 inline-block text-sky-300 hover:underline"
        >
          ← Back to assessments
        </Link>
      </main>
    );
  }

  const assessmentLabel =
    run.assessment?.title ??
    (run.assessmentId ? `Assessment #${run.assessmentId}` : "Assessment");

  const vendorLabel =
    run.vendor?.name ?? (run.vendorId ? `Vendor #${run.vendorId}` : "Vendor");

  return (
    <main className="container-page py-10">
      <div className="mb-6">
        <Link href="/assessment" className="text-sky-300 hover:underline">
          ← Back to assessments
        </Link>
      </div>

      <header className="mb-8">
        <h1 className="text-3xl font-semibold text-white">Assessment Run</h1>
        <p className="mt-2 text-white/70">
          {assessmentLabel} · {vendorLabel}
        </p>
      </header>

      <section className="glass-soft rounded-xl p-6">
        <dl className="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
          <div>
            <dt className="text-white/60">Run ID</dt>
            <dd className="text-white">{run.id}</dd>
          </div>

          <div>
            <dt className="text-white/60">Status</dt>
            <dd className="text-white">{run.status ?? "—"}</dd>
          </div>

          <div>
            <dt className="text-white/60">Started</dt>
            <dd className="text-white">
              {run.startedAt ? new Date(run.startedAt).toLocaleString() : "—"}
            </dd>
          </div>

          <div>
            <dt className="text-white/60">Completed</dt>
            <dd className="text-white">
              {run.completedAt
                ? new Date(run.completedAt).toLocaleString()
                : "—"}
            </dd>
          </div>

          <div>
            <dt className="text-white/60">Created</dt>
            <dd className="text-white">
              {run.createdAt ? new Date(run.createdAt).toLocaleString() : "—"}
            </dd>
          </div>

          <div>
            <dt className="text-white/60">Updated</dt>
            <dd className="text-white">
              {run.updatedAt ? new Date(run.updatedAt).toLocaleString() : "—"}
            </dd>
          </div>
        </dl>
      </section>
    </main>
  );
}
