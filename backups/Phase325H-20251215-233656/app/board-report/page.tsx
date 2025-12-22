// app/board-report/page.tsx
import Link from "next/link";
import prisma from "@/lib/prisma";
import { Prisma } from "@prisma/client";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

function clsx(...parts: Array<string | false | null | undefined>) {
  return parts.filter(Boolean).join(" ");
}

function pct(n: number) {
  if (!Number.isFinite(n)) return 0;
  return Math.max(0, Math.min(100, Math.round(n)));
}

function formatDate(value: string | Date) {
  const d = typeof value === "string" ? new Date(value) : value;
  return d.toLocaleDateString(undefined, {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}

function metricCard(title: string, value: string | number, hint?: string) {
  return (
    <div className="rounded-2xl border border-white/10 bg-white/5 p-4 shadow-sm print:border-black/15 print:bg-white">
      <div className="text-xs font-medium text-slate-200/70 print:text-slate-600">
        {title}
      </div>
      <div className="mt-2 text-2xl font-semibold tracking-tight text-slate-50 print:text-slate-900">
        {value}
      </div>
      {hint ? (
        <div className="mt-1 text-xs text-slate-200/50 print:text-slate-600">
          {hint}
        </div>
      ) : null}
    </div>
  );
}

function severityTone(sev: string) {
  switch (sev) {
    case "CRITICAL":
      return "border-rose-500/30 bg-rose-500/10 text-rose-200 print:border-rose-500/30 print:bg-rose-500/10 print:text-rose-700";
    case "HIGH":
      return "border-amber-500/30 bg-amber-500/10 text-amber-200 print:border-amber-500/30 print:bg-amber-500/10 print:text-amber-700";
    case "MEDIUM":
      return "border-sky-500/30 bg-sky-500/10 text-sky-200 print:border-sky-500/30 print:bg-sky-500/10 print:text-sky-700";
    case "LOW":
      return "border-emerald-500/30 bg-emerald-500/10 text-emerald-200 print:border-emerald-500/30 print:bg-emerald-500/10 print:text-emerald-700";
    default:
      return "border-white/10 bg-white/5 text-slate-200/70 print:border-black/15 print:bg-white print:text-slate-700";
  }
}

/**
 * ✅ Enum-safe status buckets using Prisma DMMF
 * This eliminates the "Status enum fallback" badge when your schema has a status enum,
 * and prevents Prisma validation errors (e.g., IN_PROGRESS not present).
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

  // If we found the enum but none of our common labels match, we still avoid crashes:
  // treat "active" as everything except accepted/resolved.
  const accepted = ACCEPTED.length ? ACCEPTED : enumFound ? [] : ["ACCEPTED_RISK"];
  const resolved = RESOLVED.length ? RESOLVED : enumFound ? [] : ["RESOLVED", "CLOSED"];

  const active =
    ACTIVE.length
      ? ACTIVE
      : enumFound
        ? [...values].filter((v) => !accepted.includes(v) && !resolved.includes(v))
        : ["OPEN"];

  return { active, accepted, resolved, enumFound };
}

function postureLabel(score: number) {
  if (score >= 85) return { label: "Strong", hint: "Healthy trust posture" };
  if (score >= 70) return { label: "Moderate", hint: "Monitor key controls" };
  if (score >= 50) return { label: "At risk", hint: "Remediation needed" };
  return { label: "Critical", hint: "Escalate and mitigate" };
}

function barTone(score: number) {
  if (score >= 85) return "bg-emerald-500/70 print:bg-emerald-500";
  if (score >= 70) return "bg-sky-500/70 print:bg-sky-500";
  if (score >= 50) return "bg-amber-500/70 print:bg-amber-500";
  return "bg-rose-500/70 print:bg-rose-500";
}

function quarterKey(d: Date) {
  const y = d.getFullYear();
  const q = Math.floor(d.getMonth() / 3) + 1;
  return `${y}-Q${q}`;
}
function startOfQuarter(d: Date) {
  const y = d.getFullYear();
  const q = Math.floor(d.getMonth() / 3);
  return new Date(y, q * 3, 1, 0, 0, 0, 0);
}
function addQuarters(d: Date, n: number) {
  const dt = new Date(d);
  dt.setMonth(dt.getMonth() + n * 3);
  return dt;
}

type TrendRow = {
  quarter: string;
  open: number;
  accepted: number;
  resolved: number;
  total: number;
};

type CiaRollup = {
  c: number;
  i: number;
  a: number;
};

function normalizeCiaValue(v: any): "C" | "I" | "A" | null {
  if (!v) return null;
  const s = String(v).toUpperCase();

  // Accept forms like "CIA", "C", "I", "A", "CONFIDENTIALITY", etc.
  if (s.includes("CONF") || s === "C") return "C";
  if (s.includes("INTEG") || s === "I") return "I";
  if (s.includes("AVAIL") || s === "A") return "A";

  if (s === "CIA") return null; // not specific
  return null;
}

export default async function BoardReportPage({
  searchParams,
}: {
  searchParams?: Promise<Record<string, string | string[] | undefined>>;
}) {
  const sp = (await searchParams) ?? {};
  const print = (() => {
    const v = Array.isArray(sp.print) ? sp.print[0] : sp.print;
    return v === "1" || String(v).toLowerCase() === "true";
  })();

  const IssueModel: any = (prisma as any).issue ?? (prisma as any).finding;

  // ✅ Pass the real model name to DMMF bucket builder
  const modelName: "Issue" | "Finding" = (prisma as any).issue ? "Issue" : "Finding";
  const { active, accepted, resolved } = buildStatusBuckets(modelName);

  // --- Counts / Vendors / Scores ---
  const vendorCountP = prisma.vendor.count().catch(() => 0);
  const evidenceCountP = prisma.evidence.count().catch(() => 0);
  const assessmentsCountP =
    ((prisma as any).assessment?.count?.().catch(() => 0) as Promise<number>) ??
    Promise.resolve(0);

  const openIssueCountP = IssueModel
    ? IssueModel.count({ where: { status: { in: active } } }).catch(() => 0)
    : Promise.resolve(0);

  const acceptedRiskCountP = IssueModel
    ? IssueModel.count({ where: { status: { in: accepted } } }).catch(() => 0)
    : Promise.resolve(0);

  const resolvedCountP = IssueModel
    ? IssueModel.count({ where: { status: { in: resolved } } }).catch(() => 0)
    : Promise.resolve(0);

  const topVendorsP = prisma.vendor
    .findMany({
      select: { id: true, name: true, riskScore: true, createdAt: true },
      orderBy: [{ riskScore: "desc" as any }, { createdAt: "desc" as any }],
      take: 10,
    })
    .catch(() => []);

  const vendorScoresP = prisma.vendor
    .findMany({ select: { riskScore: true } })
    .catch(() => []);

  const evidenceVendorsP = prisma.evidence
    .groupBy({ by: ["vendorId"], _count: { _all: true } })
    .catch(() => []);

  const openBySeverityP = IssueModel
    ? IssueModel
        .groupBy({
          by: ["severity"],
          _count: { _all: true },
          where: { status: { in: active } },
        })
        .catch(() => [])
    : Promise.resolve([]);

  const [
    vendorCount,
    evidenceCount,
    assessmentsCount,
    openIssueCount,
    acceptedRiskCount,
    resolvedFindingCount,
    topVendors,
    vendorScores,
    evidenceVendors,
    openBySeverity,
  ] = await Promise.all([
    vendorCountP,
    evidenceCountP,
    assessmentsCountP,
    openIssueCountP,
    acceptedRiskCountP,
    resolvedCountP,
    topVendorsP,
    vendorScoresP,
    evidenceVendorsP,
    openBySeverityP,
  ]);

  // --- Trust posture ---
  const scores = (vendorScores as any[])
    .map((r) => (typeof r?.riskScore === "number" ? r.riskScore : null))
    .filter((n): n is number => n != null);

  const avgRisk = scores.length
    ? scores.reduce((a, b) => a + b, 0) / scores.length
    : 0;
  const trustHealth = pct(avgRisk);
  const posture = postureLabel(trustHealth);

  // --- Evidence coverage ---
  const vendorsWithEvidence = new Set<number>(
    (evidenceVendors as any[])
      .map((r) => Number(r.vendorId))
      .filter((n) => Number.isFinite(n))
  );
  const evidenceCoverage = vendorCount ? pct((vendorsWithEvidence.size / vendorCount) * 100) : 0;

  // --- Severity mix ---
  const sevCounts: Record<string, number> = { CRITICAL: 0, HIGH: 0, MEDIUM: 0, LOW: 0 };
  let sevTotal = 0;
  for (const row of openBySeverity as any[]) {
    const key = String(row?.severity ?? "");
    const c = Number(row?._count?._all ?? 0);
    if (!Number.isFinite(c) || c <= 0) continue;
    if (sevCounts[key] == null) sevCounts[key] = 0;
    sevCounts[key] += c;
    sevTotal += c;
  }

  // =========================================================
  // NEXT LAYER 1: CIA rollups per vendor (best-effort)
  // =========================================================
  const ciaByVendor: Record<number, CiaRollup> = {};
  let ciaAvailable = false;

  for (const v of topVendors as any[]) {
    ciaByVendor[v.id] = { c: 0, i: 0, a: 0 };
  }

  if (IssueModel && (topVendors as any[]).length > 0) {
    const vendorIds = (topVendors as any[]).map((v) => v.id);

    const trySelects: Array<{ select: any; label: string }> = [
      { label: "cia", select: { id: true, vendorId: true, status: true, cia: true } },
      {
        label: "ciaImpact",
        select: { id: true, vendorId: true, status: true, ciaImpact: true },
      },
      { label: "pillar", select: { id: true, vendorId: true, status: true, pillar: true } },
    ];

    for (const attempt of trySelects) {
      try {
        const rows = await IssueModel.findMany({
          where: {
            vendorId: { in: vendorIds },
            status: { in: active },
          },
          select: attempt.select,
          take: 2000,
        });

        const prop = Object.keys(attempt.select).find(
          (k) => !["id", "vendorId", "status"].includes(k)
        );
        if (!prop) break;

        ciaAvailable = true;

        for (const r of rows as any[]) {
          const vid = Number(r.vendorId);
          if (!Number.isFinite(vid) || !ciaByVendor[vid]) continue;

          const raw = r[prop];
          const letter = normalizeCiaValue(raw);

          if (!letter && prop === "pillar") {
            const s = String(raw ?? "").toUpperCase();
            const mapped =
              s.includes("CONF")
                ? "C"
                : s.includes("INTEG")
                  ? "I"
                  : s.includes("AVAIL")
                    ? "A"
                    : null;
            if (mapped) {
              if (mapped === "C") ciaByVendor[vid].c += 1;
              if (mapped === "I") ciaByVendor[vid].i += 1;
              if (mapped === "A") ciaByVendor[vid].a += 1;
            }
            continue;
          }

          if (!letter) continue;
          if (letter === "C") ciaByVendor[vid].c += 1;
          if (letter === "I") ciaByVendor[vid].i += 1;
          if (letter === "A") ciaByVendor[vid].a += 1;
        }

        break;
      } catch {
        // try next attempt
      }
    }
  }

  // =========================================================
  // NEXT LAYER 2: Quarterly trend strip (last 8 quarters)
  // =========================================================
  const trend: TrendRow[] = [];
  let trendAvailable = false;

  const qNow = startOfQuarter(new Date());
  const qStart = addQuarters(qNow, -7);

  const qKeys: string[] = [];
  for (let i = 0; i < 8; i++) qKeys.push(quarterKey(addQuarters(qStart, i)));

  const trendMap: Record<string, TrendRow> = {};
  for (const q of qKeys)
    trendMap[q] = { quarter: q, open: 0, accepted: 0, resolved: 0, total: 0 };

  if (IssueModel) {
    const tryDateFields = ["createdAt", "updatedAt"] as const;

    for (const dateField of tryDateFields) {
      try {
        const rows = await IssueModel.findMany({
          where: {
            // @ts-ignore
            [dateField]: { gte: qStart },
          },
          select: { status: true, createdAt: true, updatedAt: true },
          take: 10000,
        });

        trendAvailable = true;

        for (const r of rows as any[]) {
          const dt = new Date(r[dateField]);
          if (Number.isNaN(dt.getTime())) continue;
          const q = quarterKey(dt);
          if (!trendMap[q]) continue;

          const st = String(r.status ?? "");
          if (active.includes(st)) trendMap[q].open += 1;
          else if (accepted.includes(st)) trendMap[q].accepted += 1;
          else if (resolved.includes(st)) trendMap[q].resolved += 1;

          trendMap[q].total += 1;
        }
        break;
      } catch {
        // try next date field
      }
    }
  }

  for (const q of qKeys) trend.push(trendMap[q]);

  // =========================================================
  // NEXT LAYER 3: Print mode styling (white board pack)
  // =========================================================
  const printHref = print ? "/board-report" : "/board-report?print=1";

  const lastGenerated = new Date();

  return (
    <main
      className={clsx(
        "container-page py-10",
        print && "print:bg-white bg-white text-slate-900",
        !print && "bg-transparent"
      )}
    >
      <style
        // eslint-disable-next-line react/no-danger
        dangerouslySetInnerHTML={{
          __html: `
          @media print {
            a { text-decoration: none !important; color: inherit !important; }
            .no-print { display: none !important; }
            .print-card { break-inside: avoid; page-break-inside: avoid; }
          }
          `,
        }}
      />

      <div className="mb-7 flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between print-card">
        <div>
          <div
            className={clsx(
              "inline-flex items-center gap-2 rounded-full border px-3 py-1 text-xs font-semibold",
              print
                ? "border-emerald-600/30 bg-emerald-600/10 text-emerald-800"
                : "border-emerald-500/20 bg-emerald-500/10 text-emerald-200"
            )}
          >
            Truvern Integrity Seal <span className="opacity-80">·</span> Verified
          </div>

          <h1
            className={clsx(
              "mt-3 text-3xl font-semibold tracking-tight",
              print ? "text-slate-900" : "text-slate-50"
            )}
          >
            Board Report
          </h1>

          <p className={clsx("mt-1 text-sm", print ? "text-slate-700" : "text-slate-200/70")}>
            Executive snapshot of vendor posture, evidence coverage, and issue governance.
          </p>

          <div className={clsx("mt-2 text-xs", print ? "text-slate-600" : "text-slate-200/50")}>
            Generated: {formatDate(lastGenerated)}
          </div>
        </div>

        <div className="no-print flex flex-wrap items-center gap-2">
          <Link
            href="/issues"
            className="rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm font-medium text-slate-50 hover:bg-white/10"
          >
            View issues
          </Link>
          <Link
            href="/api/board-report/export"
            className="rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm font-medium text-slate-50 hover:bg-white/10"
          >
            Export CSV
          </Link>
          <Link
            href={printHref}
            className="rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm font-medium text-slate-50 hover:bg-white/10"
          >
            {print ? "Exit print mode" : "Print mode"}
          </Link>
        </div>
      </div>

      <div className="mb-6 rounded-2xl border border-white/10 bg-white/5 p-5 print-card print:border-black/15 print:bg-white">
        <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <div
              className={clsx(
                "text-xs font-medium",
                print ? "text-slate-600" : "text-slate-200/70"
              )}
            >
              Trust posture
            </div>
            <div className="mt-1 flex items-end gap-3">
              <div
                className={clsx(
                  "text-3xl font-semibold tracking-tight",
                  print ? "text-slate-900" : "text-slate-50"
                )}
              >
                {trustHealth}%
              </div>
              <div className={clsx("pb-1 text-sm", print ? "text-slate-700" : "text-slate-200/70")}>
                <span
                  className={clsx(
                    "font-semibold",
                    print ? "text-slate-900" : "text-slate-50"
                  )}
                >
                  {posture.label}
                </span>{" "}
                <span className="opacity-80">·</span> {posture.hint}
              </div>
            </div>
          </div>

          <div className={clsx("text-xs", print ? "text-slate-600" : "text-slate-200/60")}>
            Based on average vendor risk score
          </div>
        </div>

        <div
          className={clsx(
            "mt-4 h-3 w-full overflow-hidden rounded-full",
            print ? "bg-slate-200" : "bg-black/30"
          )}
        >
          <div
            className={clsx("h-full rounded-full", barTone(trustHealth))}
            style={{ width: `${trustHealth}%` }}
          />
        </div>
      </div>

      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4 print-card">
        {metricCard("Vendors", vendorCount)}
        {metricCard("Evidence items", evidenceCount)}
        {metricCard("Assessments", assessmentsCount)}
        {metricCard("Open issues", openIssueCount, "Excludes Accepted Risk")}
      </div>

      <div className="mt-4 grid gap-3 lg:grid-cols-3 print-card">
        {metricCard("Accepted risk", acceptedRiskCount, "Governance decision recorded")}
        {metricCard("Resolved findings", resolvedFindingCount)}
        {metricCard(
          "Evidence coverage",
          `${evidenceCoverage}%`,
          `${vendorsWithEvidence.size}/${vendorCount || 0} vendors have evidence`
        )}
      </div>

      <div className="mt-6 rounded-2xl border border-white/10 bg-white/5 p-5 print-card print:border-black/15 print:bg-white">
        <div className="flex items-center justify-between">
          <div className={clsx("text-sm font-semibold", print ? "text-slate-900" : "text-slate-50")}>
            Quarterly trend (Open vs Accepted vs Resolved)
          </div>
          <div className={clsx("text-xs", print ? "text-slate-600" : "text-slate-200/60")}>
            Last 8 quarters {trendAvailable ? "" : "· limited data"}
          </div>
        </div>

        <div className="mt-4 grid grid-cols-8 gap-2">
          {trend.map((t) => {
            const total = t.total || 1;
            const o = pct((t.open / total) * 100);
            const a = pct((t.accepted / total) * 100);
            const r = pct((t.resolved / total) * 100);

            return (
              <div key={t.quarter} className="min-w-0">
                <div className={clsx("text-[11px] font-semibold", print ? "text-slate-700" : "text-slate-200/70")}>
                  {t.quarter}
                </div>

                <div className={clsx("mt-2 h-16 w-full overflow-hidden rounded-lg", print ? "bg-slate-200" : "bg-black/30")}>
                  <div className="flex h-full w-full flex-col">
                    <div className="bg-slate-500/60 print:bg-slate-500" style={{ height: `${o}%` }} />
                    <div className="bg-amber-500/60 print:bg-amber-500" style={{ height: `${a}%` }} />
                    <div className="bg-emerald-500/60 print:bg-emerald-500" style={{ height: `${r}%` }} />
                  </div>
                </div>

                <div className={clsx("mt-2 text-[11px]", print ? "text-slate-600" : "text-slate-200/50")}>
                  {t.total}
                </div>
              </div>
            );
          })}
        </div>

        <div className={clsx("mt-3 flex flex-wrap items-center gap-2 text-[11px]", print ? "text-slate-600" : "text-slate-200/60")}>
          <span className="inline-flex items-center gap-1">
            <span className="inline-block h-2 w-2 rounded bg-slate-500/70 print:bg-slate-500" /> Open
          </span>
          <span className="inline-flex items-center gap-1">
            <span className="inline-block h-2 w-2 rounded bg-amber-500/70 print:bg-amber-500" /> Accepted
          </span>
          <span className="inline-flex items-center gap-1">
            <span className="inline-block h-2 w-2 rounded bg-emerald-500/70 print:bg-emerald-500" /> Resolved
          </span>
        </div>
      </div>

      <div className="mt-6 grid gap-4 lg:grid-cols-2">
        <div className="rounded-2xl border border-white/10 bg-white/5 p-5 print-card print:border-black/15 print:bg-white">
          <div className="flex items-center justify-between">
            <div className={clsx("text-sm font-semibold", print ? "text-slate-900" : "text-slate-50")}>
              Open issue severity mix
            </div>
            <div className={clsx("text-xs", print ? "text-slate-600" : "text-slate-200/60")}>
              Total open:{" "}
              <span className={clsx("font-semibold", print ? "text-slate-900" : "text-slate-100/90")}>
                {sevTotal}
              </span>
            </div>
          </div>

          <div className="mt-4 space-y-3">
            {(["CRITICAL", "HIGH", "MEDIUM", "LOW"] as const).map((sev) => {
              const c = sevCounts[sev] ?? 0;
              const p = sevTotal ? pct((c / sevTotal) * 100) : 0;
              return (
                <div key={sev}>
                  <div className="flex items-center justify-between">
                    <span
                      className={clsx(
                        "inline-flex items-center rounded-full border px-2.5 py-1 text-[11px] font-semibold tracking-wide",
                        severityTone(sev)
                      )}
                    >
                      {sev}
                    </span>
                    <span className={clsx("text-xs", print ? "text-slate-600" : "text-slate-200/60")}>
                      {c} <span className="opacity-60">·</span> {p}%
                    </span>
                  </div>
                  <div className={clsx("mt-2 h-2 w-full overflow-hidden rounded-full", print ? "bg-slate-200" : "bg-black/30")}>
                    <div className={clsx("h-full rounded-full", barTone(50 + p / 2))} style={{ width: `${p}%` }} />
                  </div>
                </div>
              );
            })}
          </div>
        </div>

        <div className="rounded-2xl border border-white/10 bg-white/5 p-5 print-card print:border-black/15 print:bg-white">
          <div className="flex items-center justify-between">
            <div className={clsx("text-sm font-semibold", print ? "text-slate-900" : "text-slate-50")}>
              Top 10 riskiest vendors
            </div>
            <Link
              href="/trust-network"
              className={clsx(
                "text-xs font-semibold",
                print ? "text-emerald-700" : "text-emerald-200/90 hover:text-emerald-200"
              )}
            >
              View Trust Network →
            </Link>
          </div>

          <div className={clsx("mt-4 overflow-hidden rounded-xl border", print ? "border-black/15" : "border-white/10")}>
            <div
              className={clsx(
                "grid grid-cols-12 gap-2 border-b px-3 py-2 text-[11px] font-semibold",
                print ? "border-black/10 bg-slate-50 text-slate-600" : "border-white/10 bg-black/20 text-slate-200/70"
              )}
            >
              <div className="col-span-6">Vendor</div>
              <div className="col-span-2 text-right">Risk</div>
              <div className="col-span-3 text-right">CIA (open)</div>
              <div className="col-span-1 text-right">ID</div>
            </div>

            {(topVendors as any[]).length === 0 ? (
              <div className={clsx("px-3 py-6 text-center text-sm", print ? "text-slate-600" : "text-slate-200/60")}>
                No vendors found yet.
              </div>
            ) : (
              <div className={clsx("divide-y", print ? "divide-black/10" : "divide-white/10")}>
                {(topVendors as any[]).map((v) => {
                  const score = typeof v.riskScore === "number" ? v.riskScore : null;
                  const roll = ciaByVendor[v.id] ?? { c: 0, i: 0, a: 0 };

                  return (
                    <Link
                      key={v.id}
                      href={`/vendors/${v.id}`}
                      className={clsx("grid grid-cols-12 gap-2 px-3 py-3", print ? "hover:bg-slate-50" : "hover:bg-white/5")}
                    >
                      <div className={clsx("col-span-6 truncate text-sm font-semibold", print ? "text-slate-900" : "text-slate-50")}>
                        {v.name ?? `Vendor #${v.id}`}
                      </div>

                      <div className={clsx("col-span-2 text-right text-sm", print ? "text-slate-900" : "text-slate-100/90")}>
                        {score == null ? "—" : `${Math.round(score)}`}
                      </div>

                      <div className={clsx("col-span-3 text-right text-xs", print ? "text-slate-700" : "text-slate-200/70")}>
                        {ciaAvailable ? (
                          <span className="tabular-nums">
                            C {roll.c} · I {roll.i} · A {roll.a}
                          </span>
                        ) : (
                          <span className="opacity-70">—</span>
                        )}
                      </div>

                      <div className={clsx("col-span-1 text-right text-xs", print ? "text-slate-600" : "text-slate-200/50")}>
                        #{v.id}
                      </div>
                    </Link>
                  );
                })}
              </div>
            )}
          </div>

          <div className={clsx("mt-3 text-xs", print ? "text-slate-600" : "text-slate-200/60")}>
            Ranked by highest vendor risk score. CIA rollup counts open issues tagged to
            confidentiality/integrity/availability.
            {!ciaAvailable ? " (CIA tags not detected in current schema.)" : ""}
          </div>
        </div>
      </div>

      <div className="mt-6 rounded-2xl border border-white/10 bg-white/5 p-5 print-card print:border-black/15 print:bg-white">
        <div className={clsx("text-sm font-semibold", print ? "text-slate-900" : "text-slate-50")}>
          Board interpretation
        </div>
        <ul className={clsx("mt-2 list-disc space-y-1 pl-5 text-sm", print ? "text-slate-700" : "text-slate-200/70")}>
          <li>
            <span className={clsx("font-medium", print ? "text-slate-900" : "text-slate-100/90")}>
              Open issues
            </span>{" "}
            are active remediation items and should drive near-term execution.
          </li>
          <li>
            <span className={clsx("font-medium", print ? "text-slate-900" : "text-slate-100/90")}>
              Accepted risk
            </span>{" "}
            reflects a documented exception and should appear as governance, not “unresolved work.”
          </li>
          <li>
            <span className={clsx("font-medium", print ? "text-slate-900" : "text-slate-100/90")}>
              Resolved findings
            </span>{" "}
            remain in the audit trail for assurance and regulatory reporting.
          </li>
        </ul>
      </div>
    </main>
  );
}
