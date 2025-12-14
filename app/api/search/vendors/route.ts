// app/api/search/vendors/route.ts
import { NextResponse } from "next/server";
import prisma from "@/lib/prisma";

export async function GET(req: Request) {
  try {
    const { searchParams } = new URL(req.url);
    const q = searchParams.get("q")?.trim() ?? "";
    const takeParam = searchParams.get("take");
    const take = takeParam ? Math.min(parseInt(takeParam, 10) || 8, 20) : 8;

    if (!q) {
      return NextResponse.json({ vendors: [] });
    }

    const vendors = await prisma.vendor.findMany({
      where: {
        name: {
          contains: q,
          mode: "insensitive",
        },
      },
      orderBy: {
        createdAt: "desc",
      },
      take,
      select: {
        id: true,
        name: true,
        riskScore: true,
        createdAt: true,
      },
    });

    return NextResponse.json({ vendors });
  } catch (err) {
    console.error("Vendor search error", err);
    return new NextResponse("Internal error", { status: 500 });
  }
}
