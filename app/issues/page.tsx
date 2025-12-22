// app/issues/page.tsx
import Link from "next/link";
import prisma from "@/lib/prisma";
import { requireDbOrganization } from "@/lib/org-db";
import OrgRequired from "@/components/org-required";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

function clsx(...parts: Array<string | false | null | undefined>) {
  return parts.filter(Boolean).join(" ");
}

function sevTone(sev: string) {
  const s = (sev || "").toUpperCase();
  if (s === "CRITICAL") return "border-rose-400/25 bg-rose-500/15 text-rose-200";
  if (s === "HIGH") return "border-amber-400/25 bg-amber-500/15 text-amber-200";
  if (s === "MEDIUM") return "border-sky-400/25 bg-sky-500/15 text-sky-200";
  if (s === "LOW") return "border-emerald-400/25 bg-emerald-500/15 text-emerald-200";
  return "border-white/10 bg-white/5 text-white/80";
}

function statusTone(st: string) {
  const s = (st || "").toUpperCase();
  if (s.includes("RESOLV") || s === "DONE" || s === "CLOSED") return "border-emerald-400/20 bg-emerald-500/10 text-emerald-200";
  if (s.includes("ACCEPT")) return "border-amber-400/20 bg-amber-500/10 text-amber-200";
  if (s.includes("IN_PROGRESS") || s.includes("IN PROGRESS")) return "border-sky-400/20 bg-sky-500/10 text-sky-200";
  return "border-white/10 bg-white/5 text-white/70";
}

export default async function IssuesPage() {
  const org = await requireDbOrganization();

  if ((org as any)._needsOrgSelection) {
    return (
      <main className="container-page py-10">
        <section className="glass-soft p-6">
          <div className="flex items-center justify-between gap-3">
            <div>
              <h1 className="text-2xl font-semibold text-white">Issues</h1>
              <p className="mt-1 text-sm text-white/60">
                Issues are scoped to an organization.
              </p>
            </div>
            <Link className="btn-glass" href="/select-org">
              Select org
            </Link>
          </div>

          <div className="mt-4 max-w-2xl">
            <OrgRequired
              title="Select or create an organization to view Issues"
              subtitle="Issues are scoped to an organization. Choose one to continue."
            />
          </div>
        </section>
      </main>
    );
  }

  let issues: any[] = [];
  try {
    issues = await prisma.issue.findMany({
      where: { orgId: (org as any).id } as any,
      orderBy: [{ createdAt: "desc" }, { id: "desc" }],
      take: 200,
      select: {
        id: true,
        title: true,
        severity: true as any,
        status: true as any,
        createdAt: true,
      } as any,
    });
  } catch {
    issues = await prisma.issue.findMany({
      orderBy: [{ createdAt: "desc" }, { id: "desc" }],
      take: 100,
      select: { id: true, title: true, createdAt: true } as any,
    });
  }

  return (
    <main className="container-page py-10">
      {/* Trust Network-style header */}
      <section className="glass-soft p-5">
        <div className="flex flex-wrap items-start justify-between gap-4">
          <div>
            <div className="flex items-center gap-2">
              <h1 className="text-2xl font-semibold text-white">Issues</h1>
              <span className="pill">{issues.length} shown</span>
            </div>
            <div className="mt-1 text-sm text-white/60">
              Org: <span className="text-white/80">{(org as any).name}</span>
            </div>
          </div>

          <div className="flex flex-wrap items-center gap-2">
            <Link className="btn-primary" href="/issues/new">
              New issue
            </Link>
            <Link className="btn-glass" href="/vendors">
              Vendors
            </Link>
          </div>
        </div>

        {/* UI-only controls (safe, no state) */}
        <div className="mt-4 flex flex-wrap items-center gap-2">
          <input className="input-glass max-w-md" placeholder="Search issues (next phase)..." />
          <span className="pill">Sort: newest</span>
          <span className="pill">Scope: org</span>
        </div>
      </section>

      {/* List */}
      <section className="mt-4 glass overflow-hidden">
        {issues.length === 0 ? (
          <div className="p-6 text-white/70 text-sm">No issues yet.</div>
        ) : (
          <div className="divide-y divide-white/10">
            {issues.map((it) => {
              const title = it.title ?? `Issue #${it.id}`;
              const sev = it.severity ? String(it.severity) : "";
              const st = it.status ? String(it.status) : "";

              return (
                <Link key={it.id} href={`/issues/${it.id}`} className="block hover:bg-white/5">
                  <div className="px-5 py-4">
                    <div className="flex items-start justify-between gap-4">
                      <div className="min-w-0">
                        <div className="truncate text-sm font-semibold text-white">{title}</div>

                        <div className="mt-2 flex flex-wrap items-center gap-2">
                          {sev ? (
                            <span className={clsx("rounded-full border px-2.5 py-1 text-[11px] font-medium", sevTone(sev))}>
                              Severity: {sev}
                            </span>
                          ) : (
                            <span className="pill">Severity: —</span>
                          )}

                          {st ? (
                            <span className={clsx("rounded-full border px-2.5 py-1 text-[11px] font-medium", statusTone(st))}>
                              Status: {st}
                            </span>
                          ) : null}

                          {it.createdAt ? (
                            <span className="pill">
                              Created{" "}
                              {(() => {
                                try {
                                  return new Date(it.createdAt as any).toLocaleDateString();
                                } catch {
                                  return "—";
                                }
                              })()}
                            </span>
                          ) : null}
                        </div>
                      </div>

                      <div className="shrink-0 text-xs text-white/50 tabular-nums">#{it.id}</div>
                    </div>
                  </div>
                </Link>
              );
            })}
          </div>
        )}
      </section>
    </main>
  );
}
