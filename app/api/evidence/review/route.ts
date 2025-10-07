export const runtime = "nodejs";
export const dynamic = "force-dynamic";

import { NextResponse } from "next/server";
import { getServerSession } from "next-auth";
import { authOptions } from "@/lib/auth";

export async function GET() {
  try {
    const session = await getServerSession(authOptions);
    const email = (session?.user as any)?.email as string | undefined;
    if (!email) return NextResponse.json({ items: [] }, { status: 200 });

    // Lazy import prisma only at request time (avoids build-time issues)
    const { prisma } = await import("@/lib/prisma");

    const memberships = await prisma.membership.findMany({
      where: { user: { email } },
      select: { organizationId: true },
    });

    const orgIds = (memberships as Array<{ organizationId: string | number }>)
      .map(m => m.organizationId);
    if (orgIds.length === 0) return NextResponse.json({ items: [] }, { status: 200 });

    const items = await prisma.evidence.findMany({
      where: {
        vendor: { organizationId: { in: orgIds as any[] } },
        status: { in: ["submitted", "in-review"] },
      },
      orderBy: { updatedAt: "desc" },
      take: 100,
    });

    return NextResponse.json({ items }, { status: 200 });
  } catch {
    // Never fail build analysis; just return a benign payload
    return NextResponse.json({ items: [], error: "internal" }, { status: 200 });
  }
}