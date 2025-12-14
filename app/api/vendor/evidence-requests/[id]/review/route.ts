import { NextRequest, NextResponse } from "next/server";
import prisma from "@/lib/prisma";

export async function POST(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params;
    const requestId = Number(id);
    if (Number.isNaN(requestId)) {
      return NextResponse.json({ error: "Invalid request id" }, { status: 400 });
    }

    const body = await req.json().catch(() => ({}));
    const action = body?.action === "APPROVE" ? "APPROVED" : body?.action === "REJECT" ? "REJECTED" : null;
    const reviewerNote = typeof body?.reviewerNote === "string" ? body.reviewerNote : "";

    if (!action) {
      return NextResponse.json({ error: "Invalid action" }, { status: 400 });
    }

    const reqRow = await prisma.evidenceRequest.findUnique({
      where: { id: requestId },
      select: { id: true, status: true },
    });
    if (!reqRow) return NextResponse.json({ error: "Not found" }, { status: 404 });

    // Find latest iteration
    const latest = await prisma.evidenceRequestIteration.findFirst({
      where: { evidenceRequestId: requestId },
      orderBy: { submittedAt: "desc" },
      select: { id: true, status: true },
    });

    if (!latest) {
      return NextResponse.json(
        { error: "No submissions yet" },
        { status: 409 }
      );
    }

    // You typically only review SUBMITTED
    if (String(latest.status) !== "SUBMITTED") {
      // still allow, but it means you are re-reviewing
    }

    await prisma.$transaction(async (tx) => {
      await tx.evidenceRequestIteration.update({
        where: { id: latest.id },
        data: {
          status: action as any,
          reviewerNote,
          reviewedAt: new Date(),
        },
      });

      await tx.evidenceRequest.update({
        where: { id: requestId },
        data: {
          status: action as any,
          reviewedAt: new Date(),
        } as any,
      });
    });

    return NextResponse.json({ ok: true });
  } catch (err: any) {
    return NextResponse.json(
      { error: err?.message ?? "Unknown error" },
      { status: 500 }
    );
  }
}
