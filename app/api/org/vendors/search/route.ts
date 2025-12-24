// app/api/org/vendors/search/route.ts
import { NextRequest, NextResponse } from "next/server";
import prisma from "@/lib/prisma";
import { requireDbOrganization } from "@/lib/org-db";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET(req: NextRequest) {
  try {
    const org = await requireDbOrganization();

    const { searchParams } = new URL(req.url);
    const qRaw = (searchParams.get("q") || "").trim();

    const vendors = await prisma.vendor.findMany({
      where: {
        organizationId: org.id,
        ...(qRaw
          ? {
              name: { contains: qRaw, mode: "insensitive" as any },
            }
          : {}),
      } as any,
      orderBy: [{ updatedAt: "desc" as any }, { id: "desc" as any }] as any,
      take: 10,
      select: { id: true, name: true },
    });

    return NextResponse.json({ ok: true, vendors });
  } catch (e: any) {
    return NextResponse.json({ ok: false, error: e?.message || "Search failed" }, { status: 500 });
  }
}
