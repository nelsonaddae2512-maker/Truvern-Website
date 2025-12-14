// app/api/issues/route.ts
import { NextRequest, NextResponse } from "next/server";
import prisma from "@/lib/prisma";

export const runtime = "nodejs";

function parseIntSafe(v: string | null) {
  if (!v) return null;
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
}

export async function GET(req: NextRequest) {
  try {
    const { searchParams } = new URL(req.url);

    const vendorId = parseIntSafe(searchParams.get("vendorId"));
    const assessmentId = parseIntSafe(searchParams.get("assessmentId"));

    const status = searchParams.get("status"); // OPEN, IN_REVIEW, RESOLVED, ACCEPTED_RISK
    const severity = searchParams.get("severity"); // LOW, MEDIUM, HIGH, CRITICAL
    const q = (searchParams.get("q") ?? "").trim();

    const take = Math.min(parseInt(searchParams.get("take") ?? "50", 10) || 50, 200);

    // NOTE: If/when you add org auth context, add organizationId scoping here.
    const where: any = {};

    if (vendorId != null) where.vendorId = vendorId;
    if (assessmentId != null) where.assessmentId = assessmentId;
    if (status) where.status = status;
    if (severity) where.severity = severity;

    if (q) {
      where.OR = [
        { title: { contains: q, mode: "insensitive" } },
        { description: { contains: q, mode: "insensitive" } },
        { vendor: { name: { contains: q, mode: "insensitive" } } },
      ];
    }

    const items = await prisma.issue.findMany({
      where,
      orderBy: [{ openedAt: "desc" }, { id: "desc" }],
      take,
      include: {
        vendor: { select: { id: true, name: true } },
        assessment: { select: { id: true, status: true, title: true } },
      },
    });

    const counts = await prisma.issue.groupBy({
      by: ["status"],
      _count: { _all: true },
      where,
    }).catch(() => []);

    return NextResponse.json({ ok: true, items, counts });
  } catch (e: any) {
    return NextResponse.json(
      { ok: false, error: e?.message ?? "Unknown error" },
      { status: 500 }
    );
  }
}
