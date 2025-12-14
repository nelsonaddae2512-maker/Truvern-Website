import { NextRequest, NextResponse } from "next/server";
import prisma from "@/lib/prisma";

export async function DELETE(
  _req: NextRequest,
  context: { params: Promise<{ id: string }> }
) {
  try {
    // On your Next version, params is a Promise
    const { id } = await context.params;

    const vendorId = Number(id);

    if (!id || Number.isNaN(vendorId)) {
      return NextResponse.json(
        { error: "Valid vendor ID is required." },
        { status: 400 }
      );
    }

    // Safety: block delete if vendor still has evidence
    const evidenceCount = await prisma.evidence.count({
      where: { vendorId },
    });

    if (evidenceCount > 0) {
      return NextResponse.json(
        {
          error:
            "Cannot delete vendor that still has evidence. Please delete or archive evidence first.",
        },
        { status: 400 }
      );
    }

    // Hard delete vendor (no deletedAt needed)
    await prisma.vendor.delete({
      where: { id: vendorId },
    });

    return NextResponse.json({ success: true }, { status: 200 });
  } catch (error: any) {
    console.error("Error deleting vendor:", error);
    return NextResponse.json(
      {
        error:
          error?.message ||
          "Failed to delete vendor. Make sure the vendor exists.",
      },
      { status: 500 }
    );
  }
}
