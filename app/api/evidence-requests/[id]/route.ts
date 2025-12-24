// app/api/evidence-requests/[id]/route.ts
import { NextResponse } from "next/server";
import prisma from "@/lib/prisma";
import { requireDbOrganization } from "@/lib/org-db";

export const runtime = "nodejs";

function json(status: number, payload: any) {
  return NextResponse.json(payload, { status });
}

function parseNumericId(raw: any): number {
  const s = Array.isArray(raw) ? raw[0] : raw;
  const m = String(s ?? "").match(/\d+/);
  return m ? Number(m[0]) : NaN;
}

function isMissingFieldError(msg: string) {
  const m = (msg || "").toLowerCase();
  return m.includes("unknown argument") || m.includes("unknown arg") || m.includes("unknown field");
}

function isInvalidEnumOrValue(msg: string) {
  const m = (msg || "").toLowerCase();
  return (
    m.includes("invalid value") ||
    m.includes("is not a valid") ||
    m.includes("expected one of") ||
    (m.includes("enum") && m.includes("expected"))
  );
}

function devOrgIdFromHeaders(req: Request): number | null {
  if (process.env.NODE_ENV === "production") return null;

  const devKey = req.headers.get("x-dev-seed-key") || "";
  const expected = process.env.DEV_SEED_KEY || "local-dev";
  if (devKey !== expected) return null;

  const raw = req.headers.get("x-org-id");
  const n = Number(raw);
  if (!Number.isFinite(n) || n <= 0) return null;
  return n;
}

async function getOrgId(req: Request): Promise<number | null> {
  const devOrgId = devOrgIdFromHeaders(req);
  if (devOrgId) return devOrgId;

  try {
    const org = await requireDbOrganization();
    const id = Number((org as any)?.id);
    return Number.isFinite(id) && id > 0 ? id : null;
  } catch {
    return null;
  }
}

export async function PATCH(req: Request, ctx: { params: Promise<{ id: string }> }) {
  try {
    const orgId = await getOrgId(req);
    if (!orgId) {
      return json(409, { ok: false, needsOrgSelection: true, error: "Organization context required" });
    }

    const { id } = await ctx.params;
    const evidenceRequestId = parseNumericId(id);
    if (!Number.isFinite(evidenceRequestId)) {
      return json(400, { ok: false, error: "Invalid id" });
    }

    let body: any = null;
    try {
      body = await req.json();
    } catch {
      return json(400, { ok: false, error: "Invalid JSON body" });
    }

    const nextStatus = String(body?.status ?? "").trim();
    if (!nextStatus) {
      return json(400, { ok: false, error: "status is required" });
    }

    // Load request (must exist)
    const reqRow: any = await (prisma as any).evidenceRequest.findFirst({
      where: { id: evidenceRequestId } as any,
      select: { id: true, vendorId: true } as any,
    });

    if (!reqRow?.vendorId) {
      return json(404, { ok: false, error: "Evidence request not found" });
    }

    // Verify vendor belongs to org
    const vendor = await prisma.vendor.findFirst({
      where: { id: Number(reqRow.vendorId), organizationId: Number(orgId) } as any,
      select: { id: true } as any,
    });

    if (!vendor) {
      return json(403, { ok: false, error: "Forbidden" });
    }

    // Schema-safe update across likely lifecycle field names.
    const candidates = ["status", "requestStatus", "state", "lifecycle"];

    let lastErr: string | null = null;

    for (const field of candidates) {
      try {
        const updated = await (prisma as any).evidenceRequest.update({
          where: { id: evidenceRequestId } as any,
          data: { [field]: nextStatus } as any,
          select: { id: true, vendorId: true, [field]: true } as any,
        });

        return json(200, { ok: true, request: updated, fieldUsed: field });
      } catch (e: any) {
        const msg = e?.message ?? String(e);
        lastErr = msg;

        if (isMissingFieldError(msg)) continue;

        if (isInvalidEnumOrValue(msg)) {
          return json(400, {
            ok: false,
            error: "Invalid lifecycle value",
            debug: msg,
            attemptedField: field,
          });
        }

        return json(500, {
          ok: false,
          error: "EvidenceRequest update failed",
          debug: msg,
          attemptedField: field,
        });
      }
    }

    return json(500, {
      ok: false,
      error: "No lifecycle field found on EvidenceRequest",
      debug: lastErr ?? "Tried fields: status, requestStatus, state, lifecycle",
    });
  } catch (e: any) {
    return json(500, { ok: false, error: "Unhandled error", debug: e?.message ?? String(e) });
  }
}
