// app/api/evidence/create/route.ts
import { NextResponse } from "next/server";
import prisma from "@/lib/prisma";
import { EvidenceKind } from "@prisma/client";
import { auth } from "@clerk/nextjs/server";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

function jsonError(status: number, error: string, debug?: any) {
  return NextResponse.json({ ok: false, error, debug: debug ?? null }, { status });
}

function asString(v: any) {
  return typeof v === "string" ? v : null;
}
function asNumber(v: any) {
  const n = typeof v === "number" ? v : typeof v === "string" ? Number(v) : NaN;
  return Number.isFinite(n) ? n : null;
}

function resolveEvidenceKind(input: any): EvidenceKind {
  const values = Object.values(EvidenceKind) as string[];
  const s = asString(input);
  if (s && values.includes(s)) return s as EvidenceKind;
  return EvidenceKind.OTHER;
}

async function getDbOrgFromClerk() {
  const { orgId } = auth();
  if (!orgId) return null;

  return prisma.organization.findUnique({
    where: { clerkOrgId: orgId },
  });
}

export async function POST(req: Request) {
  try {
    // 🔐 Resolve org from Clerk
    const org = await getDbOrgFromClerk();
    if (!org) return jsonError(401, "No active organization");

    const body = await req.json().catch(() => ({}));

    const vendorId = asNumber(body?.vendorId);
    if (!vendorId) return jsonError(400, "Missing or invalid vendorId");

    const title = asString(body?.title)?.trim();
    if (!title) return jsonError(400, "Missing title");

    const fileUrl = asString(body?.fileUrl)?.trim();
    if (!fileUrl) return jsonError(400, "Missing fileUrl");

    // 🔒 Verify vendor belongs to org
    const vendor = await prisma.vendor.findFirst({
      where: {
        id: vendorId,
        organizationId: org.id,
      },
      select: { id: true },
    });

    if (!vendor) {
      return jsonError(403, "Vendor does not belong to organization");
    }

    const description = asString(body?.description);
    const kind = resolveEvidenceKind(body?.kind);

    const created = await prisma.evidence.create({
      data: {
        vendorId,
        organizationId: org.id,
        title,
        description: description ?? null,
        fileUrl,
        uploadedAt: new Date(),
        kind,
      },
      select: {
        id: true,
        vendorId: true,
        organizationId: true,
        title: true,
        description: true,
        fileUrl: true,
        uploadedAt: true,
        kind: true,
      },
    });

    return NextResponse.json({ ok: true, evidence: created });
  } catch (e: any) {
    return jsonError(500, "Internal error", {
      name: e?.name ?? "Error",
      message: e?.message ?? String(e),
      code: e?.code ?? null,
    });
  }
}
