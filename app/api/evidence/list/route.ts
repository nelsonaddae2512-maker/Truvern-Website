import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export const runtime = "nodejs";

export async function GET(req: NextRequest) {
  const vendorId = req.nextUrl.searchParams.get("vendorId");

  if (!vendorId)
    return NextResponse.json({ error: "Missing vendorId" }, { status: 400 });

  try {
    const ev = await prisma.evidence.findMany({
      where: { vendorId: Number(vendorId) },
      orderBy: { createdAt: "desc" },
    });

    return NextResponse.json(ev, { status: 200 });
  } catch (err) {
    console.error("Evidence list failed:", err);
    return NextResponse.json({ error: "Failed to load evidence" }, { status: 500 });
  }
}
