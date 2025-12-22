// app/api/evidence-requests/route.ts
import { NextResponse } from "next/server";
import prisma from "@/lib/prisma";
import { requireDbOrganization } from "@/lib/org-db";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

function json(status: number, data: any) {
  return NextResponse.json(data, { status });
}

function bad(status: number, error: string) {
  return json(status, { ok: false, error });
}

function parseDateOrNull(v: any): Date | null {
  if (v == null || v === "") return null;
  const d = new Date(v);
  return Number.isNaN(d.getTime()) ? null : d;
}

export async function POST(req: Request) {
  const org = await requireDbOrganization();

  let body: any = null;
  try {
    body = await req.json();
  } catch {
    return bad(400, "Invalid JSON body.");
  }

  const vendorId = Number(body?.vendorId);
  if (!Number.isFinite(vendorId)) return bad(400, "vendorId is required.");

  // ✅ Org-scoped vendor lookup + archived block
  const vendor = await prisma.vendor.findFirst({
    where: { id: vendorId, organizationId: org.id },
    select: { id: true, deletedAt: true },
  });

  if (!vendor) return bad(404, "Vendor not found.");
  if (vendor.deletedAt) {
    return bad(409, "Vendor is archived. Restore to create evidence requests.");
  }

  const label = String(body?.label ?? "").trim();
  if (!label) return bad(400, "label is required.");

  const kind = String(body?.kind ?? "OTHER").trim() || "OTHER";
  const description = body?.description == null ? null : String(body.description);

  const dueAtRaw = body?.dueAt ?? null;
  const dueAt = parseDateOrNull(dueAtRaw);
  if (dueAtRaw && !dueAt) return bad(400, "Invalid dueAt date.");

  const requestedBy = body?.requestedBy == null ? null : String(body.requestedBy);

  const created = await prisma.evidenceRequest.create({
    data: {
      vendorId,
      organizationId: org.id,
      kind: kind as any,
      label,
      description,
      dueAt,
      requestedBy,
      status: "OPEN" as any,
    },
    select: { id: true, vendorId: true, status: true, createdAt: true },
  });

  return json(201, { ok: true, evidenceRequest: created });
}
