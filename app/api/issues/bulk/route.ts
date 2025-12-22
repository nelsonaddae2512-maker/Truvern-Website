// app/api/issues/bulk/route.ts
import { NextRequest, NextResponse } from "next/server";
import prisma from "@/lib/prisma";
import { auth } from "@clerk/nextjs/server";
import { getCurrentOrgId } from "@/lib/current-org";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

function devBypassEnabled() {
  return (
    process.env.NODE_ENV !== "production" &&
    process.env.TRUVERN_DEV_BYPASS_AUTH === "1"
  );
}

function toInt(v: any): number | null {
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
}

function uniqInts(arr: any[]): number[] {
  const out: number[] = [];
  const seen = new Set<number>();
  for (const v of arr ?? []) {
    const n = toInt(v);
    if (!n) continue;
    if (n <= 0) continue;
    if (seen.has(n)) continue;
    seen.add(n);
    out.push(n);
  }
  return out;
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

/**
 * Enum-safe status buckets using Prisma DMMF.
 * (Duplicated intentionally to keep this route self-contained.)
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

  return { active, accepted, resolved, enumFound };
}

export async function POST(req: NextRequest) {
  try {
    const access = await requireOrgContext();
    if (!access.ok) {
      return NextResponse.json({ ok: false, error: access.error }, { status: access.status });
    }

    const body = await req.json().catch(() => null);
    const ids = uniqInts(Array.isArray(body?.ids) ? body.ids : []);
    const action = String(body?.action ?? "").toLowerCase().trim();

    if (!ids.length) {
      return NextResponse.json({ ok: false, error: "No ids provided" }, { status: 400 });
    }
    if (ids.length > 200) {
      return NextResponse.json(
        { ok: false, error: "Too many ids (max 200 per request)" },
        { status: 400 }
      );
    }

    const IssueModel: any = (prisma as any).issue ?? (prisma as any).finding;
    if (!IssueModel) {
      return NextResponse.json(
        { ok: false, error: "No Prisma model issue/finding found" },
        { status: 500 }
      );
    }

    const modelName: "Issue" | "Finding" = (prisma as any).issue ? "Issue" : "Finding";
    const buckets = buildStatusBuckets(modelName);

    const nextStatus =
      action === "accept"
        ? (buckets.accepted[0] ?? "ACCEPTED_RISK")
        : action === "resolve"
          ? (buckets.resolved[0] ?? "RESOLVED")
          : action === "reopen"
            ? (buckets.active[0] ?? "OPEN")
            : null;

    if (!nextStatus) {
      return NextResponse.json(
        { ok: false, error: "Invalid action. Use accept|resolve|reopen." },
        { status: 400 }
      );
    }

    const result = await IssueModel.updateMany({
      where: {
        id: { in: ids },
        organizationId: access.organizationId,
      },
      data: {
        status: nextStatus,
        updatedAt: new Date(),
      },
    });

    return NextResponse.json(
      {
        ok: true,
        updated: Number(result?.count ?? 0),
        status: nextStatus,
      },
      { status: 200 }
    );
  } catch (e: any) {
    console.error("[api/issues/bulk] error", e);
    return NextResponse.json({ ok: false, error: "Server error" }, { status: 500 });
  }
}
