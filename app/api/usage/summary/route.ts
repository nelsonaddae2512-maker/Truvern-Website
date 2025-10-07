export const runtime = "nodejs";
export const dynamic = "force-dynamic";

import { NextResponse } from "next/server";

/**
 * Returns a usage summary for the current user's organization.
 * - Lazy-imports NextAuth and Prisma inside the handler (no top-level side effects)
 * - Soft-fails to {} if schema/table is missing
 */
export async function GET() {
  try {
    const { getServerSession } = await import("next-auth");
    const { authOptions } = await import("@/lib/auth");
    const { prisma } = await import("@/lib/prisma");

    const session = await getServerSession(authOptions);
    const me = session?.user as any;

    // If you key usage by organizationId on user profile:
    if (!me?.organizationId) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    // Try reading usage; if table not present, return empty items
    let items: any[] = [];
    try {
      // Adjust your schema/table/columns here as needed
      items = await prisma.usage?.findMany?.({
        where: { organizationId: me.organizationId },
        orderBy: { createdAt: "desc" },
        take: 100
      }) ?? [];
    } catch {
      items = [];
    }

    // Minimal summary (customize freely)
    const total = items.length;
    return NextResponse.json({ ok: true, total, items }, { status: 200 });
  } catch {
    // Never break build: always return a benign payload
    return NextResponse.json({ ok: false, items: [] }, { status: 200 });
  }
}