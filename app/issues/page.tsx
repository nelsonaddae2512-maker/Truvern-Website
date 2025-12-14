// app/issues/page.tsx
import Link from "next/link";
import prisma from "@/lib/prisma";
import { getCurrentOrgId } from "@/lib/current-org";

function badgeClass(sev: string) {
  switch (sev) {
    case "CRITICAL":
      return "bg-rose-500/15 text-rose-200 ring-1 ring-rose-500/30";
    case "HIGH":
      return "bg-amber-500/15 text-amber-200 ring-1 ring-amber-500/30";
    case "MEDIUM":
      return "bg-sky-500/15 text-sky-200 ring-1 ring-sky-500/30";
    case "LOW":
    default:
      return "bg-emerald-500/15 text-emerald-200 ring-1 ring-emerald-500/30";
  }
}

export default async function IssuesPage() {
  const orgId = await getCurrentOrgId();

  // If you’re not signed in / no org yet, show a clean empty state (no crash)
  if (!orgId) {
    return (
      <main className="max-w-6xl mx-auto px-6 py-10">
        <h1 className="text-4xl font-semibold tracking-tight">Issues</h1>
        <p className="mt-3 text-slate-300/80">
          Sign in and join an organization to view issues.
        </p>
        <div className="mt-8 rounded-3xl border border-white/10 bg-white/5 p-6 text-slate-300/80">
          No organization context found for this user.
        </div>
      </main>
    );
  }

  const issues = await prisma.issue.findMany({
    where: { organizationId: orgId },
    orderBy: [{ openedAt: "desc" }, { id: "desc" }],
    take: 50,
    include: {
      vendor: { select: { id: true, name: true, slug: true } },
    },
  });

  return (
    <main className="max-w-6xl mx-auto px-6 py-10">
      <div className="flex items-end justify-between gap-6">
        <div>
          <h1 className="text-4xl font-semibold tracking-tight">Issues</h1>
          <p className="mt-3 text-slate-300/80">
            Your cross-vendor findings inbox (generated from assessments + manual tracking).
          </p>
        </div>

        <Link
          href="/assessment"
          className="rounded-xl bg-emerald-500/15 px-3 py-2 text-sm text-emerald-200 ring-1 ring-emerald-500/30 hover:bg-emerald-500/20"
        >
          Run assessment
        </Link>
      </div>

      <div className="mt-8 rounded-3xl border border-white/10 bg-white/5 p-6">
        {issues.length === 0 ? (
          <div className="text-slate-300/80">No issues found.</div>
        ) : (
          <div className="divide-y divide-white/10">
            {issues.map((i) => (
              <Link
                key={i.id}
                href={`/issues/${Number(i.id)}`}
                className="block py-4 hover:bg-white/5 -mx-3 px-3 rounded-xl transition"
              >
                <div className="flex items-start justify-between gap-4">
                  <div className="min-w-0">
                    <div className="flex items-center gap-2">
                      <span
                        className={`inline-flex items-center rounded-full px-2 py-0.5 text-xs ${badgeClass(
                          String(i.severity)
                        )}`}
                      >
                        {String(i.severity)}
                      </span>
                      <span className="text-sm text-slate-300/80">
                        {String(i.status)}
                      </span>
                    </div>
                    <div className="mt-1 text-lg font-medium truncate">{i.title}</div>
                    <div className="mt-1 text-sm text-slate-300/70 truncate">
                      {i.vendor?.name ? `Vendor: ${i.vendor.name}` : "Vendor: —"}
                      {i.dueAt
                        ? ` • Due: ${new Date(i.dueAt).toLocaleDateString()}`
                        : ""}
                    </div>
                  </div>

                  <div className="shrink-0 text-sm text-slate-400">#{i.id}</div>
                </div>
              </Link>
            ))}
          </div>
        )}
      </div>
    </main>
  );
}
