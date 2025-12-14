// app/api/evidence/route.ts
import { NextRequest, NextResponse } from "next/server";
import prisma from "@/lib/prisma";

export async function GET(req: NextRequest) {
  try {
    const { searchParams } = new URL(req.url);

    const vendorIdParam = searchParams.get("vendorId");
    const takeParam = searchParams.get("take");
    const cursorParam = searchParams.get("cursor");
    const kindParam = searchParams.get("kind"); // optional filter
    const includeDeletedParam = searchParams.get("includeDeleted");

    const where: {
      vendorId?: number;
      kind?: string;
      deletedAt?: null;
    } = {};

    if (vendorIdParam) {
      const vendorId = Number(vendorIdParam);
      if (!Number.isNaN(vendorId)) {
        where.vendorId = vendorId;
      }
    }

    // kind filter (REPORT / POLICY / CERTIFICATE / SCREENSHOT / OTHER)
    if (kindParam && kindParam !== "ALL") {
      where.kind = kindParam.toUpperCase();
    }

    // only show non-deleted unless explicitly overridden
    const includeDeleted =
      includeDeletedParam === "1" || includeDeletedParam === "true";
    if (!includeDeleted) {
      where.deletedAt = null;
    }

    const take = takeParam ? Math.min(parseInt(takeParam, 10) || 20, 100) : 20;
    const cursor = cursorParam ? { id: Number(cursorParam) } : undefined;

    const items = await prisma.evidence.findMany({
      where,
      orderBy: { uploadedAt: "desc" },
      take: take + 1, // simple "hasMore" pagination
      cursor,
    });

    let nextCursor: number | null = null;
    let sliced = items;
    if (items.length === take + 1) {
      const last = items[items.length - 1];
      nextCursor = last.id;
      sliced = items.slice(0, -1);
    }

    return NextResponse.json({
      items: sliced,
      nextCursor,
    });
  } catch (err: any) {
    console.error("Error loading evidence:", err);
    return NextResponse.json(
      {
        error: err?.message ?? "Failed to load evidence.",
      },
      { status: 500 }
    );
  }
}
