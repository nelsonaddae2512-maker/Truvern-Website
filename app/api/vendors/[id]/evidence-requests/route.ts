// app/api/vendors/[id]/evidence-requests/route.ts
import { NextResponse } from "next/server";
import prisma from "@/lib/prisma";
import { Prisma } from "@prisma/client";
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

function getIterationsRelationName() {
  const m = Prisma.dmmf.datamodel.models.find((x) => x.name === "EvidenceRequest");
  const rel = (m?.fields ?? []).find(
    (f) => f.kind === "object" && f.type === "EvidenceRequestIteration" && f.isList === true
  );
  return rel?.name ?? null;
}

function evidenceRequestFieldSet() {
  const m = Prisma.dmmf.datamodel.models.find((x) => x.name === "EvidenceRequest");
  return new Set((m?.fields ?? []).map((f) => f.name));
}

function devOrgIdFromHeaders(req: Request): number | null {
  // Dev-only bypass: lets PowerShell hit routes without Clerk cookies
  if (process.env.NODE_ENV === "production") return null;

  const devKey = String(req.headers.get("x-dev-seed-key") || "").trim();
  const expected = String(process.env.DEV_SEED_KEY || "").trim();

  // Accept either:
  // - exact match to DEV_SEED_KEY (if set), OR
  // - "local-dev" fallback for your PowerShell calls
  const ok =
    (expected && devKey === expected) ||
    devKey === "local-dev";

  if (!ok) return null;

  const raw = String(req.headers.get("x-org-id") || "").trim();
  const n = Number(raw);
  if (!Number.isFinite(n) || n <= 0) return null;

  return n;
}

async function getOrgId(req: Request): Promise<{ orgId: number | null; mode: "dev" | "clerk" | "none" }> {
  const devOrgId = devOrgIdFromHeaders(req);
  if (devOrgId) return { orgId: devOrgId, mode: "dev" };

  try {
    const org = await requireDbOrganization();
    const id = Number((org as any)?.id);
    if (Number.isFinite(id) && id > 0) return { orgId: id, mode: "clerk" };
    return { orgId: null, mode: "none" };
  } catch {
    return { orgId: null, mode: "none" };
  }
}

function debugHeaders(req: Request) {
  // return only the bits we care about
  return {
    "x-dev-seed-key": req.headers.get("x-dev-seed-key"),
    "x-org-id": req.headers.get("x-org-id"),
    cookie: req.headers.get("cookie") ? "(present)" : "(none)",
    nodeEnv: process.env.NODE_ENV,
    devSeedEnv: process.env.DEV_SEED_KEY ? "(set)" : "(not set)",
  };
}

export async function GET(req: Request, ctx: { params: Promise<{ id: string }> }) {
  try {
    const { id } = await ctx.params;
    const vendorId = parseNumericId(id);
    if (!Number.isFinite(vendorId)) {
      return json(400, { ok: false, error: "Invalid vendor id", debugHeaders: debugHeaders(req) });
    }

    const { orgId, mode } = await getOrgId(req);
    if (!orgId) {
      return json(409, {
        ok: false,
        needsOrgSelection: true,
        error: "Organization context required",
        debugHeaders: debugHeaders(req),
        orgMode: mode,
      });
    }

    const vendor = await prisma.vendor.findFirst({
      where: { id: vendorId, organizationId: orgId } as any,
      select: { id: true } as any,
    });

    if (!vendor) {
      return json(403, { ok: false, error: "Forbidden", orgId, orgMode: mode, debugHeaders: debugHeaders(req) });
    }

    const relName = getIterationsRelationName();

    const rows = await prisma.evidenceRequest.findMany({
      where: { vendorId } as any,
      orderBy: [{ id: "desc" }] as any,
      ...(relName
        ? { include: { [relName]: { orderBy: [{ id: "desc" }] as any } } as any }
        : {}),
    } as any);

    return json(200, { ok: true, items: rows, iterationsRel: relName, orgMode: mode, orgId, debugHeaders: debugHeaders(req) });
  } catch (err: any) {
    console.error(err);
    return json(500, { ok: false, error: "List failed", debug: err?.message ?? String(err) });
  }
}

export async function POST(req: Request, ctx: { params: Promise<{ id: string }> }) {
  try {
    const { id } = await ctx.params;
    const vendorId = parseNumericId(id);
    if (!Number.isFinite(vendorId)) {
      return json(400, { ok: false, error: "Invalid vendor id", debugHeaders: debugHeaders(req) });
    }

    const { orgId, mode } = await getOrgId(req);
    if (!orgId) {
      return json(409, {
        ok: false,
        needsOrgSelection: true,
        error: "Organization context required",
        debugHeaders: debugHeaders(req),
        orgMode: mode,
      });
    }

    const vendor = await prisma.vendor.findFirst({
      where: { id: vendorId, organizationId: orgId } as any,
      select: { id: true } as any,
    });

    if (!vendor) {
      return json(403, { ok: false, error: "Forbidden", orgId, orgMode: mode, debugHeaders: debugHeaders(req) });
    }

    let body: any = null;
    try {
      body = await req.json();
    } catch {
      body = null;
    }

    const label = String(body?.label ?? body?.title ?? body?.name ?? "Evidence Request").trim();

    const fields = evidenceRequestFieldSet();
    const data: any = {};

    if (fields.has("vendorId")) data.vendorId = vendorId;

    if (fields.has("label")) data.label = label;
    if (fields.has("title")) data.title = label;
    if (fields.has("name")) data.name = label;

    if (fields.has("description")) data.description = body?.description ? String(body.description) : null;
    if (fields.has("kind")) data.kind = body?.kind ? String(body.kind) : undefined;

    // your enum has OPEN/SUBMITTED/APPROVED/REJECTED/CANCELLED
    if (fields.has("status")) data.status = "OPEN";

    if (fields.has("dueAt") && body?.dueAt) {
      const d = new Date(String(body.dueAt));
      if (!Number.isNaN(d.getTime())) data.dueAt = d;
    }

    const created = await (prisma as any).evidenceRequest.create({
      data,
      select: { id: true, vendorId: true, ...(fields.has("status") ? { status: true } : {}) } as any,
    });

    return json(200, { ok: true, request: created, orgMode: mode, orgId, debugHeaders: debugHeaders(req) });
  } catch (err: any) {
    console.error(err);
    return json(500, { ok: false, error: "Create failed", debug: err?.message ?? String(err) });
  }
}
