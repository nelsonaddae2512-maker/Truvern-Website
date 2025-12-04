import { NextResponse } from "next/server";
import prisma from "@/lib/prisma";

export async function GET() {
  try {
    const evidence = await prisma.evidence.findMany({
      orderBy: { createdAt: "desc" },
    });

    return NextResponse.json({ evidence }, { status: 200 });
  } catch (err) {
    console.error("Evidence list error:", err);
    return NextResponse.json(
      { error: "Failed to load evidence list" },
      { status: 500 }
    );
  }
}
