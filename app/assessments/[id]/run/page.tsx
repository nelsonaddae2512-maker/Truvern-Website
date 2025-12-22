// app/assessments/[id]/run/page.tsx
import Link from "next/link";
import { redirect } from "next/navigation";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

type ParamsPromise = Promise<{ id: string }>;
type Props = { params: ParamsPromise };

function parseId(raw: unknown): number | null {
  const v = Array.isArray(raw) ? raw[0] : raw;
  const s = typeof v === "string" ? v.trim() : v == null ? "" : String(v);
  const m = s.match(/\d+/);
  if (!m) return null;
  const n = Number(m[0]);
  return Number.isFinite(n) ? n : null;
}

export default async function AssessmentRunCompatPage({ params }: Props) {
  const { id } = await params;
  const runId = parseId(id);

  if (!runId) {
    return (
      <main className="container-page py-12">
        <div className="glass-soft rounded-3xl p-6">
          <h1 className="text-xl font-semibold text-slate-50">Invalid assessment id</h1>
          <p className="mt-2 text-sm text-slate-300">
            This route expects a numeric assessment/run id.
          </p>
          <div className="mt-4 flex flex-wrap gap-2">
            <Link className="btn-glass" href="/assessments">
              Back to assessments
            </Link>
            <Link className="btn-glass" href="/assessment/runs">
              View runs
            </Link>
          </div>
        </div>
      </main>
    );
  }

  // Compatibility redirect:
  // Old links point to /assessments/:id/run
  // Actual UI lives at /assessment/runs/:id
  redirect(`/assessment/runs/${runId}`);
}
