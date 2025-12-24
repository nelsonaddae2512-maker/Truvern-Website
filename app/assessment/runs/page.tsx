// app/assessment/runs/page.tsx
import Link from "next/link";

export const dynamic = "force-dynamic";

export default function RunsIndexPage() {
  return (
    <main className="container-page py-10">
      <h1 className="text-2xl font-semibold text-white">Assessment Runs</h1>
      <p className="mt-2 text-white/70">
        Select a run from an assessment to view details.
      </p>

      <div className="mt-6">
        <Link href="/assessment" className="text-sky-300 hover:underline">
          ← Back to assessments
        </Link>
      </div>
    </main>
  );
}
