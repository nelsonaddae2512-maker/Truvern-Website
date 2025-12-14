// app/api/evidence/delete/route.ts
import { NextRequest, NextResponse } from "next/server";
import prisma from "@/lib/prisma";

export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => null);

    const rawId = body?.id;
    const evidenceId =
      typeof rawId === "string" ? Number(rawId) : Number(rawId);

    if (!evidenceId || Number.isNaN(evidenceId)) {
      return NextResponse.json(
        {
          error:
            "Could not determine which evidence item to delete. Please refresh and try again.",
        },
        { status: 400 }
      );
    }

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
