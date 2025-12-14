import { NextRequest, NextResponse } from "next/server";
import prisma from "@/lib/prisma";

export async function DELETE(
  _req: NextRequest,
  context: { params: Promise<{ id: string }> }
) {
  try {
    // On your Next version params is a Promise
    const { id } = await context.params;

    const evidenceId = Number(id);

    if (!id || Number.isNaN(evidenceId)) {
      return NextResponse.json(
        { error: "Valid evidence ID is required." },
        { status: 400 }
      );
    }

    // Simple hard delete for now
    await prisma.evidence.delete({
      where: { id: evidenceId },
    });

    return NextResponse.json({ success: true }, { status: 200 });
  } catch (error: any) {
    console.error("Error deleting evidence:", error);
    return NextResponse.json(
      {
        error:
          error?.message ||
          "Failed to delete evidence. Make sure it still exists.",
      },
      { status: 500 }
    );
  }
}
