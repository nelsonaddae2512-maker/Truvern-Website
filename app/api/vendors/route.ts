// app/api/vendors/route.ts
import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export const runtime = "nodejs";

export async function GET() {
  try {
    const vendors = await prisma.vendor.findMany({
      orderBy: { name: "asc" },
      select: {
        id: true,
        name: true,
        riskScore: true,
        createdAt: true,
      },
    });

    return NextResponse.json(vendors, { status: 200 });
  } catch (err: any) {
    // This will show up in Vercel runtime logs
    console.error("[/api/vendors] ERROR:", err);

    const safeError = {
      error: "Failed to load vendors",
      // short diagnostics for us, still safe for browser
      code: err?.code ?? null,
      message: err?.message ?? null,
      meta: err?.meta ?? null,
    };

    return NextResponse.json(safeError, { status: 500 });
  }
}
