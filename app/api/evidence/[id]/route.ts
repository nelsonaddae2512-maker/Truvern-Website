// app/api/evidence/[id]/route.ts
import { NextRequest, NextResponse } from "next/server";
import prisma from "@/lib/prisma";

type RouteParams = {
  params: { id: string };
};

export async function DELETE(req: NextRequest, { params }: RouteParams) {
  try {
    const idParam = params.id;
    const evidenceId = Number(idParam);

    if (!idParam || Number.isNaN(evidenceId)) {
      return NextResponse.json(
        { error: "Valid evidence ID is required." },
        { status: 400 }
      );
    }

    const existing = await prisma.evidence.findUnique({
      where: { id: evidenceId },
      select: { id: true, deletedAt: true },
    });

    if (!existing) {
      return NextResponse.json(
        { error: "Evidence not found." },
        { status: 404 }
      );
    }

    // Soft delete
    await prisma.evidence.update({
      where: { id: evidenceId },
      data: { deletedAt: new Date() },
    });

    return NextResponse.json({ success: true }, { status: 200 });
  } catch (err: any) {
    console.error("Error deleting evidence:", err);
    return NextResponse.json(
      {
        error:
          err?.message ??
          "Unexpected error while deleting evidence. Check server logs.",
      },
      { status: 500 }
    );
  }
}
