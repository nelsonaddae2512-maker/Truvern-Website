import { NextResponse } from "next/server";
import prisma from "@/lib/prisma";
import { auth } from "@clerk/nextjs/server";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

function jsonError(message: string, status = 400, extra?: any) {
  return NextResponse.json({ ok: false, error: message, ...extra }, { status });
}

const ALLOWED_REQUEST_KINDS = new Set([
  "SOC2",
  "ISO27001",
  "PENTEST",
  "PCI",
  "SIG",
  "OTHER",
] as const);

function normalizeKind(raw: unknown) {
  const s = (typeof raw === "string" ? raw : raw == null ? "" : String(raw)).trim();
  if (!s) return "OTHER";
  if (ALLOWED_REQUEST_KINDS.has(s as any)) return s;
  throw new Error(`Invalid kind. Allowed: ${Array.from(ALLOWED_REQUEST_KINDS).join(", ")}`);
}

function hasValidDevBypass(req: Request): boolean {
  return req.headers.get("x-dev-seed-key") === "local-dev";
}

async function resolveOrgId(req: Request) {
  const dev = hasValidDevBypass(req);
  const a = auth();
  const userId = a.userId || null;
  const clerkOrgId = a.orgId || null;

  if (userId && clerkOrgId) {
    const org = await prisma.organization.findFirst({
      where: { clerkOrgId },
      select: { id: true },
    });
    if (!org) throw new Error("Signed-in org not found in DB");
    return { orgId: org.id, requestedBy: userId };
  }

  if (dev) {
    const raw = req.headers.get("x-org-id");
    const orgId = Number(String(raw ?? "").trim());
    if (!Number.isFinite(orgId) || orgId <= 0) throw new Error("Invalid x-org-id");
    return { orgId, requestedBy: userId ?? "dev-bypass" };
  }

  throw new Error("Unauthorized (missing org context)");
}

export async function POST(req: Request) {
  try {
    const { orgId, requestedBy } = await resolveOrgId(req);
    const body = await req.json();

    const vendorId = Number(body?.vendorId);
    if (!Number.isFinite(vendorId) || vendorId <= 0) return jsonError("Invalid vendorId", 400);

    const vendor = await prisma.vendor.findFirst({
      where: { id: vendorId, organizationId: orgId },
      select: { id: true },
    });
    if (!vendor) return jsonError("Vendor not found for this organization", 404);

    const kind = normalizeKind(body?.kind);
    const label = String(body?.label ?? "").trim();
    const description = String(body?.description ?? "").trim();

    if (!label) return jsonError("Missing label", 400);

    const created = await prisma.evidenceRequest.create({
      data: {
        vendorId: vendor.id,
        organizationId: orgId,
        requestedBy,
        kind: kind as any,
        label,
        description: description || null,
        dueAt: body?.dueAt ? new Date(body.dueAt) : null,
        status: "OPEN" as any, // set your desired default
      } as any,
    });

    return NextResponse.json({ ok: true, request: created });
  } catch (e: any) {
    return jsonError(e?.message || "Create evidence request failed", 400);
  }
}
