// app/api/board-report/export/route.ts
import { NextResponse } from "next/server";
import prisma from "@/lib/prisma";
import { Prisma } from "@prisma/client";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

function csvEscape(value: any) {
  if (value == null) return "";
  const s = String(value);
  if (/[",\n\r]/.test(s)) return `"${s.replace(/"/g, '""')}"`;
  return s;
}
function toCsv(rows: any[][]) {
  return rows.map((r) => r.map(csvEscape).join(",")).join("\n");
}

/**
 * ✅ Enum-safe status buckets using Prisma DMMF.
 * Prevents Prisma validation errors caused by status values not present in the enum.
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

  // If enum exists but our label candidates don't match, treat "active" as everything else
  const active =
    ACTIVE.length
      ? ACTIVE
      : enumFound
        ? [...values].filter((v) => !accepted.includes(v) && !resolved.includes(v))
        : ["OPEN"];

  return {
    active,
    accepted,
    resolved,
  };
}

export async function GET() {
  const IssueModel: any = (prisma as any).issue ?? (prisma as any).finding;

  const modelName: "Issue" | "Finding" = (prisma as any).issue ? "Issue" : "Finding";
  const { active, accepted, resolved } = buildStatusBuckets(modelName);

  const nowIso = new Date().toISOString();

  const [vendorCount, evidenceCount, assessmentsCount, openIssueCount, acceptedRiskCount, resolvedCount] =
    await Promise.all([
      prisma.vendor.count().catch(() => 0),
      prisma.evidence.count().catch(() => 0),
      (prisma as any).assessment?.count?.().catch(() => 0) ?? 0,

      IssueModel ? IssueModel.count({ where: { status: { in: active } } }).catch(() => 0) : 0,
      IssueModel ? IssueModel.count({ where: { status: { in: accepted } } }).catch(() => 0) : 0,
      IssueModel ? IssueModel.count({ where: { status: { in: resolved } } }).catch(() => 0) : 0,
    ]);

  const vendors =
    (await prisma.vendor
      .findMany({
        select: { id: true, name: true, riskScore: true, createdAt: true },
        orderBy: [{ riskScore: "desc" as any }, { createdAt: "desc" as any }],
        take: 500,
      })
      .catch(() => [])) ?? [];

  const perVendor: Record<number, { open: number; accepted: number; resolved: number; total: number }> =
    {};
  for (const v of vendors as any[]) perVendor[v.id] = { open: 0, accepted: 0, resolved: 0, total: 0 };

  if (IssueModel && vendors.length) {
    try {
      const grouped = await IssueModel.groupBy({
        by: ["vendorId", "status"],
        _count: { _all: true },
        where: { vendorId: { in: (vendors as any[]).map((v) => v.id) } },
      });

      for (const row of grouped as any[]) {
        const vid = row.vendorId;
        const status = String(row.status ?? "");
        const c = Number(row._count?._all ?? 0);
        if (!perVendor[vid]) continue;

        perVendor[vid].total += c;
        if (active.includes(status)) perVendor[vid].open += c;
        else if (accepted.includes(status)) perVendor[vid].accepted += c;
        else if (resolved.includes(status)) perVendor[vid].resolved += c;
      }
    } catch {
      await Promise.all(
        (vendors as any[]).map(async (v) => {
          const [o, a, r] = await Promise.all([
            IssueModel.count({ where: { vendorId: v.id, status: { in: active } } }).catch(() => 0),
            IssueModel.count({ where: { vendorId: v.id, status: { in: accepted } } }).catch(
              () => 0
            ),
            IssueModel.count({ where: { vendorId: v.id, status: { in: resolved } } }).catch(() => 0),
          ]);
          perVendor[v.id] = { open: o, accepted: a, resolved: r, total: o + a + r };
        })
      );
    }
  }

  const rows: any[][] = [];
  rows.push(["GeneratedAt", nowIso]);
  rows.push(["Vendors", vendorCount]);
  rows.push(["EvidenceItems", evidenceCount]);
  rows.push(["Assessments", assessmentsCount]);
  rows.push(["OpenIssues", openIssueCount]);
  rows.push(["AcceptedRisk", acceptedRiskCount]);
  rows.push(["ResolvedFindings", resolvedCount]);
  rows.push(["TotalGovernedItems", acceptedRiskCount + resolvedCount]);

  rows.push([]);
  rows.push([
    "VendorId",
    "VendorName",
    "RiskScore",
    "OpenIssues",
    "AcceptedRisk",
    "ResolvedFindings",
    "TotalIssuesAllStatuses",
  ]);

  for (const v of vendors as any[]) {
    const roll = perVendor[v.id] ?? { open: 0, accepted: 0, resolved: 0, total: 0 };
    rows.push([
      v.id,
      v.name ?? "",
      v.riskScore ?? "",
      roll.open,
      roll.accepted,
      roll.resolved,
      roll.total,
    ]);
  }

  const csv = toCsv(rows);

  return new NextResponse(csv, {
    status: 200,
    headers: {
      "Content-Type": "text/csv; charset=utf-8",
      "Content-Disposition": `attachment; filename="truvern-board-report-${nowIso.slice(
        0,
        10
      )}.csv"`,
      "Cache-Control": "no-store",
    },
  });
}
