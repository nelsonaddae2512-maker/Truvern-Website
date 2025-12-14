// app/api/issues/unread-count/route.ts
import { NextResponse } from "next/server";
import prisma from "@/lib/prisma";

export const runtime = "nodejs";

export async function GET() {
  try {
    // "Unread" in this phase = open-ish (not resolved/closed).
    // Your schema enum: OPEN, IN_REVIEW, RESOLVED, ACCEPTED_RISK
    const count = await prisma.issue.count({
      where: {
        status: { in: ["OPEN", "IN_REVIEW"] as any },
      } as any,
    });

    return NextResponse.json({ ok: true, count });
  } catch (e: any) {
    return NextResponse.json(
      { ok: false, count: 0, error: e?.message ?? "Unknown error" },
      { status: 200 }
    );
  }
}
