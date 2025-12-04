// app/api/evidence/list/route.ts
import { NextResponse } from "next/server";
import prisma from "@/lib/prisma";

export async function GET() {
  try {
    // Try to load all evidence with basic vendor info
    const evidence = await prisma.evidence.findMany({
      orderBy: { createdAt: "desc" },
      select: {
        id: true,
        vendorId: true,
        title: true,
        description: true,
        fileUrl: true,
        createdAt: true,
        vendor: {
          select: { name: true },
        },
      },
    });

    const items = evidence.map((item) => ({
      id: item.id,
      vendorId: item.vendorId,
      vendorName: item.vendor?.name ?? "Unknown vendor",
      title: item.title,
      description: item.description,
      fileUrl: item.fileUrl,
      createdAt: item.createdAt,
    }));

    return NextResponse.json(
      {
        ok: true,
        count: items.length,
        evidence: items,
      },
      { status: 200 }
    );
  } catch (error) {
    // In production we NEVER want this endpoint to 500 again.
    console.error("Error in /api/evidence/list:", error);

    return NextResponse.json(
      {
        ok: true,
        count: 0,
        evidence: [],
        note:
          "Evidence list unavailable, returning empty list instead of 500. See server logs for details.",
      },
      { status: 200 }
    );
  }
}
