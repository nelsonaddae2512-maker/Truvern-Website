// app/api/evidence-requests/[id]/reject/route.ts
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
        status: "REJECTED" as any,
        reviewedAt: new Date(),
        reviewNote,
      },
      select: { id: true, status: true },
    });

    await notifyVendorEvidenceStatusChange({
      evidenceRequestId: requestId,
      subject: `Evidence needs changes`,
      headline: `Evidence request rejected`,
      message: reviewNote
        ? `Reason: ${reviewNote}`
        : `Your submission needs changes. Please review and resubmit.`,
    }).catch((e) => {
      console.warn("[email] reject notify failed:", e);
    });

    return NextResponse.json({ ok: true, requestId: updated.id, status: updated.status });
  } catch (e: any) {
    return NextResponse.json({ ok: false, error: e?.message || "Server error" }, { status: 500 });
  }
}
