// app/api/evidence-requests/[id]/review/route.ts
import { NextRequest, NextResponse } from "next/server";
import prisma from "@/lib/prisma";

export async function POST(req: NextRequest, ctx: { params: Promise<{ id: string }> }) {
  try {
    const { id } = await ctx.params;
    const requestId = Number(id);
    if (Number.isNaN(requestId)) return NextResponse.json({ error: "Invalid id" }, { status: 400 });

    const body = await req.json().catch(() => null);
    const action = body?.action as "APPROVE" | "REJECT" | undefined;
    const noteRaw = typeof body?.note === "string" ? body.note : "";
    const note = noteRaw.trim().slice(0, 2000) || null;

    if (action !== "APPROVE" && action !== "REJECT") {
      return NextResponse.json({ error: "Invalid action" }, { status: 400 });
    }

    const existing = await prisma.evidenceRequest.findUnique({
      where: { id: requestId },
      select: { id: true, status: true, organizationId: true, vendorId: true },
    });

    if (!existing) return NextResponse.json({ error: "Not found" }, { status: 404 });

    if (String(existing.status) !== "SUBMITTED") {
      return NextResponse.json(
        { error: `Cannot review when status=${existing.status}` },
        { status: 409 }
      );
    }

    const nextStatus = action === "APPROVE" ? ("APPROVED" as any) : ("REJECTED" as any);

    const updated = await prisma.evidenceRequest.update({
      where: { id: requestId },
      data: {
        status: nextStatus,
        reviewedAt: new Date(),
        reviewNote: note,
      } as any,
      select: { id: true, organizationId: true, vendorId: true, status: true },
    });

    // Activity feed event
    if (updated.organizationId) {
      await prisma.usageEvent.create({
        data: {
          organizationId: updated.organizationId,
          vendorId: updated.vendorId,
          kind:
            action === "APPROVE"
              ? "EVIDENCE_REQUEST_APPROVED"
              : "EVIDENCE_REQUEST_REJECTED",
          details: {
            requestId: updated.id,
            status: String(updated.status),
            note,
          },
        } as any,
      });
    }

    return NextResponse.json({ ok: true });
  } catch (e: any) {
    return NextResponse.json({ error: e?.message || "Server error" }, { status: 500 });
  }
}
