// app/api/org/evidence-requests/create/route.ts
import { NextRequest, NextResponse } from "next/server";
import prisma from "@/lib/prisma";
import { requireDbOrganization } from "@/lib/org-db";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function POST(req: NextRequest) {
  try {
    const org = await requireDbOrganization();

    const body = await req.json().catch(() => ({} as any));
    const vendorId = Number(body?.vendorId);
    const label = typeof body?.label === "string" ? body.label.trim() : "";
    const description = typeof body?.description === "string" ? body.description.trim() : "";
    const kind = typeof body?.kind === "string" ? body.kind : "OTHER";
    const dueAtStr = typeof body?.dueAt === "string" ? body.dueAt : "";

    if (!Number.isFinite(vendorId)) {
      return NextResponse.json({ ok: false, error: "Invalid vendorId" }, { status: 400 });
    }
    if (!label) {
      return NextResponse.json({ ok: false, error: "Label is required" }, { status: 400 });
    }
    if (!dueAtStr) {
      return NextResponse.json({ ok: false, error: "Due date is required" }, { status: 400 });
    }

    // Parse yyyy-mm-dd into Date
    const dueAt = new Date(`${dueAtStr}T23:59:59.000Z`);
    if (Number.isNaN(dueAt.getTime())) {
      return NextResponse.json({ ok: false, error: "Invalid due date" }, { status: 400 });
    }

    // Ensure vendor belongs to org
    const vendor = await prisma.vendor.findFirst({
      where: { id: vendorId, organizationId: org.id } as any,
      select: { id: true },
    });

    if (!vendor) {
      return NextResponse.json({ ok: false, error: "Vendor not found in this org" }, { status: 404 });
    }

    const created = await prisma.evidenceRequest.create({
      data: {
        vendorId,
        organizationId: org.id,
        label,
        description: description || null,
        kind,
        dueAt,
        status: "OPEN",
      } as any,
      select: { id: true },
    });

    return NextResponse.json({ ok: true, id: created.id });
  } catch (e: any) {
    return NextResponse.json({ ok: false, error: e?.message || "Create failed" }, { status: 500 });
  }
}
