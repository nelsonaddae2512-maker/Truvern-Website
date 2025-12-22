// app/assessments/page.tsx
import Link from "next/link";
import prisma from "@/lib/prisma";

export const metadata = {
  title: "Assessments – Truvern",
  description: "Portfolio of all vendor assessments, with live scores and status.",
};

function riskTone(score: number | null | undefined): string {
  if (score == null) return "text-slate-400";
  if (score >= 85) return "text-emerald-300";
  if (score >= 70) return "text-cyan-300";
  if (score >= 50) return "text-amber-300";
  return "text-rose-300";
}

function statusBadge(status: string) {
  const base =
    "inline-flex items-center rounded-full border px-2 py-0.5 text-[10px] ";
  switch (status) {
    case "COMPLETED":
      return (
        <span className={base + "border-emerald-500/60 bg-emerald-500/10 text-emerald-200"}>
          Completed
        </span>
      );
    case "IN_PROGRESS":
      return (
        <span className={base + "border-cyan-500/60 bg-cyan-500/10 text-cyan-200"}>
          In progress
        </span>
      );
    case "DRAFT":
      return (
        <span className={base + "border-slate-600 bg-slate-800/80 text-slate-200"}>
          Draft
        </span>
      );
    case "ARCHIVED":
      return (
        <span className={base + "border-slate-700 bg-slate-900/80 text-slate-400"}>
          Archived
        </span>
      );
    default:
      return (
        <span className={base + "border-slate-700 bg-slate-900/80 text-slate-400"}>
          {status}
        </span>
      );
  }
}

export default async function AssessmentsPage() {
  const assessments = await prisma.assessment.findMany({
    orderBy: { createdAt: "desc" },
    include: {
      vendor: true,
      template: true,
    },
  });

  const rows = assessments.map((a) => ({
    id: a.id,
    title: a.title || a.template?.name || "Untitled assessment",
    vendorName: a.vendor?.name ?? "Unknown vendor",
    vendorId: a.vendorId,
    templateName: a.template?.name ?? null,
    standard: a.template?.standard ?? null,
    status: a.status,
    score: a.score,
    createdAt: a.createdAt,
    dueAt: a.dueAt ?? null,
    completedAt: a.completedAt ?? null,
  }));

  return (
    <main className="relative max-w-6xl mx-auto px-4 lg:px-6 py-12 lg:py-16">
      {/* Soft background glows */}
      <div className="pointer-events-none absolute inset-x-0 -top-32 -z-10 h-64 bg-[radial-gradient(circle_at_top,_rgba(45,212,191,0.25),transparent_60%)]" />
      <div className="pointer-events-none absolute inset-x-0 bottom-0 -z-10 h-64 bg-[radial-gradient(circle_at_bottom,_rgba(56,189,248,0.20),transparent_60%)]" />

      {/* Accent line */}
      <div className="h-px w-full bg-gradient-to-r from-emerald-400/80 via-cyan-400/70 to-violet-500/70 mb-6" />

      {/* Header */}
      <section className="glass-soft mb-5 rounded-3xl px-4 py-4 shadow-lg shadow-black/40">
        <div className="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
          <div className="space-y-1.5">
            <div className="inline-flex items-center gap-2 rounded-full bg-slate-900/70 border border-emerald-500/30 px-3 py-1">
              <span className="h-1.5 w-1.5 rounded-full bg-emerald-400" />
              <span className="text-[10px] font-semibold tracking-[0.2em] text-emerald-300 uppercase">
                Assessment portfolio
              </span>
            </div>
            <div>
              <h1 className="text-2xl lg:text-3xl font-semibold text-slate-50 tracking-tight">
                Assessments
              </h1>
              <p className="mt-1 text-[12px] text-slate-400">
                A single pane for all vendor questionnaires, their status, and
                live scores driving Truvern risk.
              </p>
            </div>
          </div>

          <div className="flex flex-col items-end gap-2">
            <Link href="/vendors" className="btn-primary text-[12px]">
              <span>Start from a vendor</span>
              <span aria-hidden>↗</span>
            </Link>
            <p className="text-[10px] text-slate-500 max-w-xs text-right">
              Pick a vendor, hit{" "}
              <span className="text-emerald-300">Start assessment</span>, and it
              will show up here as a draft or in-progress assessment.
            </p>
          </div>
        </div>
      </section>

      {/* Table */}
      <section className="glass-soft rounded-3xl px-4 py-4 shadow-lg shadow-black/40">
        <div className="flex items-center justify-between mb-3">
          <p className="text-[11px] font-semibold uppercase tracking-[0.18em] text-slate-400">
            All assessments ({rows.length})
          </p>
          <p className="text-[10px] text-slate-500">
            Click a row to jump into the assessment runner.
          </p>
        </div>

        {rows.length === 0 ? (
          <p className="text-[12px] text-slate-500 border border-dashed border-slate-700 rounded-2xl px-3 py-4 bg-slate-950/70">
            No assessments yet. Go to{" "}
            <span className="text-emerald-300">Vendors</span>, choose a vendor,
            and start your first assessment.
          </p>
        ) : (
          <div className="overflow-x-auto rounded-2xl border border-slate-800 bg-slate-950/90">
            <table className="min-w-full text-left text-[12px]">
              <thead className="border-b border-slate-800 bg-slate-950/90">
                <tr className="text-slate-400">
                  <th className="px-4 py-2 font-medium">Assessment</th>
                  <th className="px-4 py-2 font-medium">Vendor</th>
                  <th className="px-4 py-2 font-medium">Standard</th>
                  <th className="px-4 py-2 font-medium">Status</th>
                  <th className="px-4 py-2 font-medium text-right">Score</th>
                  <th className="px-4 py-2 font-medium">Created</th>
                  <th className="px-4 py-2 font-medium">Due</th>
                  <th className="px-4 py-2"></th>
                </tr>
              </thead>
              <tbody>
                {rows.map((a) => (
                  <tr
                    key={a.id}
                    className="border-t border-slate-800 hover:bg-slate-900/70 transition"
                  >
                    <td className="px-4 py-2 align-top">
                      <div className="flex flex-col gap-0.5">
                        <Link
                          href={`/assessments/${a.id}/run`}
                          className="text-slate-50 hover:text-emerald-300 font-semibold"
                        >
                          {a.title}
                        </Link>
                        {a.templateName && (
                          <p className="text-[11px] text-slate-500">
                            Template: {a.templateName}
                          </p>
                        )}
                      </div>
                    </td>
                    <td className="px-4 py-2 align-top">
                      <Link
                        href={`/vendors/${a.vendorId}`}
                        className="text-slate-200 hover:text-emerald-300"
                      >
                        {a.vendorName}
                      </Link>
                    </td>
                    <td className="px-4 py-2 align-top text-slate-300">
                      {a.standard ?? "—"}
                    </td>
                    <td className="px-4 py-2 align-top">{statusBadge(a.status)}</td>
                    <td className="px-4 py-2 align-top text-right">
                      <span className={riskTone(a.score)}>
                        {a.score == null ? "—" : `${a.score}/100`}
                      </span>
                    </td>
                    <td className="px-4 py-2 align-top text-slate-300">
                      {a.createdAt.toLocaleDateString(undefined, {
                        year: "numeric",
                        month: "short",
                        day: "numeric",
                      })}
                    </td>
                    <td className="px-4 py-2 align-top text-slate-300">
                      {a.dueAt
                        ? a.dueAt.toLocaleDateString(undefined, {
                            year: "numeric",
                            month: "short",
                            day: "numeric",
                          })
                        : "—"}
                    </td>
                    <td className="px-4 py-2 align-top text-right">
                      <Link href={`/assessments/${a.id}/run`} className="btn-glass text-[11px] px-3 py-1 rounded-full">
                        <span>Open</span>
                        <span aria-hidden>↗</span>
                      </Link>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </main>
  );
}
