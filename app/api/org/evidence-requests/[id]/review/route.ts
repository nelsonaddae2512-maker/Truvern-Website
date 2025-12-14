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

    const body = await req.json();
    const action = body?.action; // "APPROVE" | "REJECT"
    const note =
      typeof body?.note === "string" && body.note.trim()
        ? body.note.trim()
        : null;

    if (!["APPROVE", "REJECT"].includes(action)) {
      return NextResponse.json({ error: "Invalid action" }, { status: 400 });
    }

    if (action === "REJECT" && !note) {
      return NextResponse.json(
        { error: "Rejection requires a note" },
        { status: 400 }
      );
    }

    const reqRow = await prisma.evidenceRequest.findUnique({
      where: { id: requestId },
      select: { id: true, status: true },
    });

    if (!reqRow) {
      return NextResponse.json({ error: "Not found" }, { status: 404 });
    }

    if (reqRow.status === "APPROVED") {
      return NextResponse.json(
        { error: "Already approved" },
        { status: 409 }
      );
    }

    const nextStatus = action === "APPROVE" ? "APPROVED" : "REJECTED";

    await prisma.$transaction(async (tx) => {
      await tx.evidenceRequest.update({
        where: { id: requestId },
        data: {
          status: nextStatus as any,
          reviewedAt: new Date(),
          reviewNote: note,
        } as any,
      });

      // Optional: annotate latest iteration (safe, non-breaking)
      const latestIter = await tx.evidenceRequestIteration.findFirst({
        where: { evidenceRequestId: requestId },
        orderBy: { submittedAt: "desc" },
        select: { id: true },
      });

      if (latestIter) {
        await tx.evidenceRequestIteration.update({
          where: { id: latestIter.id },
          data: {
            status: nextStatus as any,
            reviewerNote: note ?? undefined,
          } as any,
        });
      }
    });

    return NextResponse.json({ ok: true, status: nextStatus });
  } catch (err: any) {
    return NextResponse.json(
      { error: err?.message ?? "Unknown error" },
      { status: 500 }
    );
  }
}
