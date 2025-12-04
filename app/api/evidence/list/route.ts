// app/api/evidence/list/route.ts
import { NextResponse } from "next/server";
import prisma from "@/lib/prisma";

export async function GET() {
  try {
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

    // Normalize into a simple array the UI / scripts can read
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
    console.error("Error in /api/evidence/list:", error);
    return NextResponse.json(
      { ok: false, error: "Failed to load evidence list" },
      { status: 500 }
    );
  }
}
