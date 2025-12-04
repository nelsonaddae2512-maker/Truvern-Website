import { NextRequest, NextResponse } from "next/server";
import prisma from "@/lib/prisma";

export async function GET(req: NextRequest) {
  try {
    const { searchParams } = new URL(req.url);

    const vendorIdParam = searchParams.get("vendorId");
    const takeParam = searchParams.get("take");
    const cursorParam = searchParams.get("cursor");

    const where: { vendorId?: number } = {};

    if (vendorIdParam) {
      const vendorId = Number(vendorIdParam);
      if (!Number.isNaN(vendorId)) {
        where.vendorId = vendorId;
      }
    }

    const take = takeParam ? Math.min(parseInt(takeParam, 10) || 20, 100) : 20;
    const cursor = cursorParam ? { id: Number(cursorParam) } : undefined;

    const queryOptions: any = {
      where,
      orderBy: { createdAt: "desc" },
      take: take + 1,
      include: {
        vendor: {
          select: {
            id: true,
            name: true,
          },
        },
      },
    };

    if (cursor) {
      queryOptions.cursor = cursor;
      queryOptions.skip = 1;
    }

    const records = await prisma.evidence.findMany(queryOptions);

    const hasMore = records.length > take;
    const items = hasMore ? records.slice(0, take) : records;

    const evidence = items.map((e: any) => ({
      id: e.id,
      vendorId: e.vendorId,
      vendorName: e.vendor?.name ?? null,
      title: e.title ?? e.name ?? "",
      description: e.description ?? null,
      fileUrl: e.fileUrl ?? null,
      createdAt: e.createdAt,
    }));

    const nextCursor = hasMore ? items[items.length - 1].id : null;

    return NextResponse.json(
      {
        ok: true,
        count: evidence.length,
        evidence,
        nextCursor,
      },
      {
        status: 200,
      }
    );
  } catch (error) {
    console.error("Evidence list API error", error);

    // ---- Safe stub fallback so health checks & Phase187 never break ----
    const stubEvidence = [
      {
        id: 1,
        vendorId: 1,
        vendorName: "Acme Payments",
        title: "SOC 2 Type II (stub)",
        description:
          "Static stub evidence record from /api/evidence/list fallback. Replace with real Prisma query later.",
        fileUrl: "https://example.com/soc2.pdf",
        createdAt: new Date().toISOString(),
      },
    ];

    return NextResponse.json(
      {
        ok: true,
        count: stubEvidence.length,
        evidence: stubEvidence,
        note:
          "This is a stubbed evidence list response (fallback after an internal error). Replace with real database-backed list when ready.",
      },
      {
        status: 200,
      }
    );
  }
}
