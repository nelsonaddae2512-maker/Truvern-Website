import { NextResponse } from "next/server";
import prisma from "@/lib/prisma";

export async function GET() {
  try {
    const runs = await prisma.assessment.findMany({
      orderBy: { updatedAt: "desc" },
      take: 200,
      include: {
        vendor: { select: { id: true, name: true } },
        template: { select: { id: true, name: true } }, // ✅ no `title`
      },
    });

    return NextResponse.json({ ok: true, runs });
  } catch (e: any) {
    return NextResponse.json(
      { ok: false, error: e?.message ?? "Failed to load assessment runs" },
      { status: 500 }
    );
  }
}
