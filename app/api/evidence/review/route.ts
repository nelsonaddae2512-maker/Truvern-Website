export const runtime = "nodejs";
export const dynamic = "force-dynamic";
import { NextResponse } from "next/server";

export async function GET(){ const { getServerSession } = await import("next-auth"); const { authOptions } = await import("@/lib/auth");  const { prisma } = await import("@/lib/prisma"); 
  try {
    // Lazy import next-auth & authOptions
    const { getServerSession } = await import("next-auth");
    const { authOptions } = await import("@/lib/auth");
    const session = await getServerSession(authOptions);
    const email = (session?.user as any)?.email as string | undefined;
    if (!email) return NextResponse.json({ items: [] }, { status: 200 });

    // Lazy import prisma only at request time
    const mod = (await import("@/lib/prisma")) as { prisma?: any };
    const prisma = mod?.prisma;
    if (!prisma) return NextResponse.json({ items: [] }, { status: 200 });

    // Orgs this reviewer belongs to
    const memberships = await prisma.membership.findMany({
      where: { user: { email } },
      select: { organizationId: true }
    });
    const orgIds = (memberships as Array<{ organizationId: string | number }>).map(m => m.organizationId);
    if (orgIds.length === 0) return NextResponse.json({ items: [] }, { status: 200 });

    // Evidence awaiting review for vendors in those orgs, newest first
    const items = await prisma.evidence.findMany({
      where: {
        vendor: { organizationId: { in: orgIds as any[] } },
        status: { in: ["submitted", "in-review"] }
      },
      orderBy: { updatedAt: "desc" },
      take: 100
    });

    return NextResponse.json({ items }, { status: 200 });
  } catch {
    // Never break “collect page data”
    return NextResponse.json({ items: [], error: "internal" }, { status: 200 });
  }
}