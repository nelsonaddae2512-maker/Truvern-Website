// app/issues/page.tsx
import Link from "next/link";
import prisma from "@/lib/prisma";
import { Prisma } from "@prisma/client";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

type TabKey = "issues" | "accepted" | "resolved";

function clsx(...parts: Array<string | false | null | undefined>) {
  return parts.filter(Boolean).join(" ");
}

function statusTone(status: string) {
  switch (status) {
    case "OPEN":
      return "bg-slate-800 text-slate-200 border-slate-700";
    case "IN_PROGRESS":
    case "IN_REMEDIATION":
    case "IN_REVIEW":
    case "PENDING":
    case "PENDING_REVIEW":
      return "bg-blue-500/10 text-blue-200 border-blue-500/30";
    case "ACCEPTED_RISK":
    case "RISK_ACCEPTED":
    case "EXCEPTION_APPROVED":
    case "ACCEPTED":
      return "bg-amber-500/10 text-amber-200 border-amber-500/30";
    case "RESOLVED":
    case "CLOSED":
    case "DONE":
    case "MITIGATED":
      return "bg-emerald-500/10 text-emerald-200 border-emerald-500/30";
    default:
      return "bg-slate-800 text-slate-200 border-slate-700";
  }
}

function severityTone(sev: string) {
  switch (sev) {
    case "CRITICAL":
      return "bg-rose-500/10 text-rose-200 border-rose-500/40";
    case "HIGH":
      return "bg-amber-500/10 text-amber-200 border-amber-500/40";
    case "MEDIUM":
      return "bg-sky-500/10 text-sky-200 border-sky-500/40";
    case "LOW":
      return "bg-emerald-500/10 text-emerald-200 border-emerald-500/40";
    default:
      return "bg-slate-800 text-slate-200 border-slate-700";
  }
}

function fmtDate(d?: Date | string | null) {
  if (!d) return "—";
  const dt = typeof d === "string" ? new Date(d) : d;
  return dt.toLocaleDateString(undefined, {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}

function normalizeBool(v: string | string[] | undefined) {
  const s = Array.isArray(v) ? v[0] : v;
  if (!s) return false;
  return s === "1" || s.toLowerCase() === "true" || s.toLowerCase() === "yes";
}

/**
 * ✅ Enum-safe status buckets using Prisma DMMF (no "enum fallback" guesses)
 * Prevents Prisma "Invalid value for argument 'in'" crashes.
 */
function buildStatusBuckets(modelName: "Issue" | "Finding") {
  const dmmf: any = (prisma as any)?._dmmf;
  const models: any[] = dmmf?.datamodel?.models ?? [];
  const enums: any[] = dmmf?.datamodel?.enums ?? [];

  const m = models.find((x) => x?.name === modelName);
  const statusField = m?.fields?.find((f: any) => f?.name === "status");

  const enumTypeName: string | null =
    statusField?.kind === "enum" ? String(statusField.type) : null;

  const enumDef = enumTypeName ? enums.find((e) => e?.name === enumTypeName) : null;

  const values = new Set<string>(
    (enumDef?.values ?? [])
      .map((v: any) => (typeof v === "string" ? v : v?.name))
      .filter(Boolean)
  );

  const pick = (candidates: string[]) => candidates.filter((s) => values.has(s));

  const ACTIVE = pick([
    "OPEN",
    "IN_PROGRESS",
    "IN_REMEDIATION",
    "IN_REVIEW",
    "PENDING",
    "PENDING_REVIEW",
  ]);

  const ACCEPTED = pick([
    "ACCEPTED_RISK",
    "RISK_ACCEPTED",
    "ACCEPTED",
    "EXCEPTION_APPROVED",
  ]);

  const RESOLVED = pick(["RESOLVED", "CLOSED", "DONE", "MITIGATED"]);

  const enumFound = values.size > 0;

  const accepted = ACCEPTED.length ? ACCEPTED : enumFound ? [] : ["ACCEPTED_RISK"];
  const resolved = RESOLVED.length ? RESOLVED : enumFound ? [] : ["RESOLVED", "CLOSED"];

  // If we found the enum but our labels don't match, treat active as "everything else"
  const active =
    ACTIVE.length
      ? ACTIVE
      : enumFound
        ? [...values].filter((v) => !accepted.includes(v) && !resolved.includes(v))
        : ["OPEN"];

  return { active, accepted, resolved, enumFound };
}

export default async function IssuesPage({
  searchParams,
}: {
  searchParams?: Promise<Record<string, string | string[] | undefined>>;
}) {
  const sp = (await searchParams) ?? {};
  const showResolved = normalizeBool(sp.showResolved);

  const tabRaw = Array.isArray(sp.tab) ? sp.tab[0] : sp.tab;
  let tab: TabKey =
    tabRaw === "accepted" || tabRaw === "resolved" || tabRaw === "issues"
      ? tabRaw
      : "issues";

  if (tab === "resolved" && !showResolved) tab = "issues";

  // ✅ Support either prisma.issue or prisma.finding (depending on your schema)
  const IssueModel: any = (prisma as any).issue ?? (prisma as any).finding;

  if (!IssueModel) {
    return (
      <main className="container-page py-10">
        <h1 className="text-2xl font-semibold tracking-tight">Issues</h1>
        <p className="mt-2 text-sm text-slate-200/70">
          Could not find a Prisma model named <code>issue</code> or{" "}
          <code>finding</code>. Check <code>prisma/schema.prisma</code>.
        </p>
      </main>
    );
  }

  // ✅ Determine schema model name for DMMF enum extraction
  const modelName: "Issue" | "Finding" = (prisma as any).issue ? "Issue" : "Finding";
  const { active, accepted, resolved, enumFound } = buildStatusBuckets(modelName);

  const whereByTab: any =
    tab === "issues"
      ? { status: { in: active } }
      : tab === "accepted"
        ? { status: { in: accepted } }
        : { status: { in: resolved } };

  const [activeCount, acceptedCount, resolvedCount] = await Promise.all([
    IssueModel.count({ where: { status: { in: active } } }).catch(() => 0),
    IssueModel.count({ where: { status: { in: accepted } } }).catch(() => 0),
    IssueModel.count({ where: { status: { in: resolved } } }).catch(() => 0),
  ]);

  const issues = await IssueModel.findMany({
    where: whereByTab,
    orderBy: [
      { severity: "desc" as any },
      { dueAt: "asc" as any },
      { updatedAt: "desc" as any },
      { createdAt: "desc" as any },
    ],
    take: 200,
    include: {
      vendor: { select: { id: true, name: true } },
    },
  });

  const tabCount =
    tab === "issues" ? activeCount : tab === "accepted" ? acceptedCount : resolvedCount;

  const visibleTabs: { key: TabKey; label: string; count: number }[] = [
    { key: "issues", label: "Issues", count: activeCount },
    { key: "accepted", label: "Accepted Risk", count: acceptedCount },
    ...(showResolved
      ? [{ key: "resolved" as const, label: "Resolved", count: resolvedCount }]
      : []),
  ];

  const tabHref = (nextTab: TabKey) =>
    `/issues?tab=${nextTab}${showResolved ? "&showResolved=1" : ""}`;

  const showResolvedHref = showResolved
    ? `/issues?tab=${tab === "resolved" ? "issues" : tab}`
    : `/issues?tab=${tab}&showResolved=1`;

  return (
    <main className="container-page py-10">
      <div className="mb-6 flex items-start justify-between gap-4">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">Issues</h1>
          <p className="mt-1 text-sm text-slate-200/70">
            Active issues exclude Accepted Risk and Resolved findings.
          </p>

          {!enumFound ? (
            <div className="mt-3 rounded-xl border border-amber-500/20 bg-amber-500/10 px-3 py-2 text-xs text-amber-100/90">
              Note: could not introspect a status enum via Prisma DMMF. Using safe fallback buckets.
            </div>
          ) : null}
        </div>

        <Link
          href="/board-report"
          className="rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm font-medium text-slate-50 hover:bg-white/10"
        >
          View board report
        </Link>
      </div>

      <div className="mb-5 flex flex-wrap items-center justify-between gap-3">
        <div className="flex flex-wrap items-center gap-2">
          {visibleTabs.map((t) => {
            const isActive = tab === t.key;
            return (
              <Link
                key={t.key}
                href={tabHref(t.key)}
                className={clsx(
                  "inline-flex items-center gap-2 rounded-full border px-3 py-1.5 text-sm",
                  isActive
                    ? "border-white/20 bg-white/10 text-slate-50"
                    : "border-white/10 bg-white/5 text-slate-200/80 hover:bg-white/10"
                )}
              >
                <span className="font-medium">{t.label}</span>
                <span className="rounded-full bg-black/20 px-2 py-0.5 text-xs text-slate-100/80">
                  {t.count}
                </span>
              </Link>
            );
          })}
        </div>

        <Link
          href={showResolvedHref}
          className={clsx(
            "rounded-full border px-3 py-1.5 text-xs font-semibold tracking-wide",
            showResolved
              ? "border-emerald-500/30 bg-emerald-500/10 text-emerald-200 hover:bg-emerald-500/15"
              : "border-white/10 bg-white/5 text-slate-200/70 hover:bg-white/10"
          )}
        >
          {showResolved ? "Hide resolved" : "Show resolved"}
        </Link>
      </div>

      <div className="rounded-2xl border border-white/10 bg-white/5">
        <div className="flex items-center justify-between border-b border-white/10 px-5 py-4">
          <div className="text-sm font-semibold text-slate-50">
            {tab === "issues"
              ? "Active issues"
              : tab === "accepted"
                ? "Accepted risk"
                : "Resolved"}
          </div>
          <div className="text-xs text-slate-200/60">{tabCount} items</div>
        </div>

        {issues.length === 0 ? (
          <div className="px-5 py-10 text-center">
            <div className="text-sm text-slate-200/70">Nothing here yet.</div>
          </div>
        ) : (
          <div className="divide-y divide-white/10">
            {issues.map((f: any) => (
              <Link
                key={f.id}
                href={`/issues/${f.id}`}
                className="block px-5 py-4 hover:bg-white/5"
              >
                <div className="flex items-start justify-between gap-4">
                  <div className="min-w-0">
                    <div className="flex flex-wrap items-center gap-2">
                      {f.severity ? (
                        <span
                          className={clsx(
                            "inline-flex items-center rounded-full border px-2.5 py-1 text-[11px] font-semibold tracking-wide",
                            severityTone(String(f.severity))
                          )}
                        >
                          {String(f.severity)}
                        </span>
                      ) : null}

                      {f.status ? (
                        <span
                          className={clsx(
                            "inline-flex items-center rounded-full border px-2.5 py-1 text-[11px] font-semibold tracking-wide",
                            statusTone(String(f.status))
                          )}
                        >
                          {String(f.status)}
                        </span>
                      ) : null}
                    </div>

                    <div className="mt-2 truncate text-base font-semibold text-slate-50">
                      {f.title ?? f.name ?? `Issue #${f.id}`}
                    </div>

                    <div className="mt-1 text-sm text-slate-200/70">
                      Vendor:{" "}
                      <span className="text-slate-100/90">
                        {f.vendor?.name ?? "—"}
                      </span>
                      {f.dueAt ? (
                        <>
                          {" "}
                          · Due:{" "}
                          <span className="text-slate-100/90">{fmtDate(f.dueAt)}</span>
                        </>
                      ) : null}
                    </div>
                  </div>

                  <div className="shrink-0 text-xs text-slate-200/50">#{f.id}</div>
                </div>
              </Link>
            ))}
          </div>
        )}
      </div>
    </main>
  );
}
