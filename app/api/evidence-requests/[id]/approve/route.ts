// app/api/evidence-requests/[id]/approve/route.ts
import { NextRequest, NextResponse } from "next/server";
import prisma from "@/lib/prisma";
import { notifyVendorEvidenceStatusChange } from "@/lib/vendor-notifications";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function POST(req: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  try {
    const { id } = await params;
    const requestId = Number(id);
    if (!Number.isFinite(requestId)) return NextResponse.json({ ok: false, error: "Invalid id" }, { status: 400 });

    const body = await req.json().catch(() => ({}));
    const reviewNote = typeof body?.reviewNote === "string" ? body.reviewNote.trim() : null;

    const updated = await prisma.evidenceRequest.update({
      where: { id: requestId },
      data: {
        status: "APPROVED" as any,
        reviewedAt: new Date(),
        reviewNote,
      },
      select: { id: true, status: true },
    });

    // notify vendor (safe no-op if no contactEmail)
    await notifyVendorEvidenceStatusChange({
      evidenceRequestId: requestId,
      subject: `Evidence approved`,
      headline: `Evidence request approved`,
      message: reviewNote ? `Reviewer note: ${reviewNote}` : `Your submission has been approved.`,
    }).catch((e) => {
      console.warn("[email] approve notify failed:", e);
    });

    return NextResponse.json({ ok: true, requestId: updated.id, status: updated.status });
  } catch (e: any) {
    return NextResponse.json({ ok: false, error: e?.message || "Server error" }, { status: 500 });
  }
}
