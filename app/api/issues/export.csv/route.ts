// app/api/issues/export.csv/route.ts
import { NextRequest, NextResponse } from "next/server";
import prisma from "@/lib/prisma";
import { auth } from "@clerk/nextjs/server";
import { getCurrentOrgId } from "@/lib/current-org";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

type TabKey = "issues" | "accepted" | "resolved";

function devBypassEnabled() {
  return (
    process.env.NODE_ENV !== "production" &&
    process.env.TRUVERN_DEV_BYPASS_AUTH === "1"
  );
}

function toInt(v: string | null): number | null {
  if (!v) return null;
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
}

function normalizeTab(v: string | null): TabKey {
  const s = String(v ?? "").toLowerCase().trim();
  if (s === "issues" || s === "accepted" || s === "resolved") return s;
  return "issues";
}

function splitCsv(v: string | null): string[] | null {
  if (!v) return null;
  const out = v
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
  return out.length ? out : null;
}

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
 * Enum-safe status buckets using Prisma DMMF.
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

  const active =
    ACTIVE.length
      ? ACTIVE
      : enumFound
        ? [...values].filter((v) => !accepted.includes(v) && !resolved.includes(v))
        : ["OPEN", "IN_REVIEW"];

  return { active, accepted, resolved };
}

async function requireOrgContext(): Promise<
  | { ok: true; organizationId: number }
  | { ok: false; status: number; error: string }
> {
  if (devBypassEnabled()) {
    const envOrg = toInt(process.env.TRUVERN_DEV_ORG_ID ?? null);
    if (envOrg) return { ok: true, organizationId: envOrg };
  }

  const orgId = await getCurrentOrgId().catch(() => null);
  if (orgId) return { ok: true, organizationId: orgId };

  const { userId } = auth();
  if (!userId) return { ok: false, status: 401, error: "Unauthorized" };
  return { ok: false, status: 403, error: "No organization context" };
}

export async function GET(req: NextRequest) {
  const access = await requireOrgContext();
  if (!access.ok) {
    return NextResponse.json({ ok: false, error: access.error }, { status: access.status });
  }

  const url = new URL(req.url);
  const tab = normalizeTab(url.searchParams.get("tab"));

  const qRaw = url.searchParams.get("q");
  const q = qRaw ? String(qRaw).trim() : "";

  const severityParam = url.searchParams.get("severity");
  const severities = splitCsv(severityParam);

  const vendorId = toInt(url.searchParams.get("vendorId"));
  const assessmentId = toInt(url.searchParams.get("assessmentId"));

  const IssueModel: any = (prisma as any).issue ?? (prisma as any).finding;
  if (!IssueModel) {
    return NextResponse.json({ ok: false, error: "No Prisma model issue/finding found" }, { status: 500 });
  }

  const modelName: "Issue" | "Finding" = (prisma as any).issue ? "Issue" : "Finding";
  const buckets = buildStatusBuckets(modelName);

  const statusIn =
    tab === "accepted" ? buckets.accepted : tab === "resolved" ? buckets.resolved : buckets.active;

  const where: any = {
    organizationId: access.organizationId,
    ...(vendorId ? { vendorId } : {}),
    ...(assessmentId ? { assessmentId } : {}),
    ...(severities && severities.length ? { severity: { in: severities } } : {}),
    ...(statusIn?.length ? { status: { in: statusIn } } : {}),
    ...(q
      ? {
          OR: [
            { title: { contains: q, mode: "insensitive" } },
            { description: { contains: q, mode: "insensitive" } },
          ],
        }
      : {}),
  };

  const orderBy: any[] = [
    { severity: "desc" as any },
    { dueAt: "asc" as any },
    { updatedAt: "desc" as any },
    { createdAt: "desc" as any },
    { id: "desc" as any },
  ];

  const rows = await IssueModel.findMany({
    where,
    orderBy,
    take: 5000, // sane cap for CSV export
    include: {
      vendor: { select: { id: true, name: true } },
      assessment: { select: { id: true, title: true } },
    },
  });

  const header = [
    "id",
    "title",
    "severity",
    "status",
    "vendorId",
    "vendorName",
    "assessmentId",
    "assessmentTitle",
    "createdAt",
  ];

  const dataRows = rows.map((r: any) => [
    r.id,
    r.title,
    r.severity,
    r.status,
    r.vendor?.id ?? "",
    r.vendor?.name ?? "",
    r.assessment?.id ?? "",
    r.assessment?.title ?? "",
    r.createdAt ? new Date(r.createdAt).toISOString() : "",
  ]);

  const csv = toCsv([header, ...dataRows]);

  const filename = `truvern-issues-${tab}-${new Date().toISOString().slice(0, 10)}.csv`;

  return new NextResponse(csv, {
    status: 200,
    headers: {
      "content-type": "text/csv; charset=utf-8",
      "content-disposition": `attachment; filename="${filename}"`,
      "cache-control": "no-store",
    },
  });
}
