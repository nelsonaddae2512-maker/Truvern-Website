import { NextResponse } from "next/server";
import { getServerSession } from "next-auth";
import { authOptions } from "@/lib/auth";

type OrgIdRow = { organizationId: string | number };

export async function GET() {
  try {
    const session = await getServerSession(authOptions);
    const email = (session?.user as any)?.email as string | undefined;
    if (!email) return NextResponse.json({ items: [] }, { status: 200 });

    // Import prisma inside the handler (safer for build)
    const { prisma } = await import("@/lib/prisma");

    // orgs this reviewer belongs to
    const memberships: OrgIdRow[] = await prisma.membership.findMany({
      where: { user: { email } },
      select: { organizationId: true }
    });
    const orgIds = memberships.map(({ organizationId }) => organizationId);
    if (orgIds.length === 0) return NextResponse.json({ items: [] }, { status: 200 });

    // latest evidence for vendors in those orgs
    const items = await prisma.evidence.findMany({
      where: { vendor: { organizationId: { in: orgIds as any[] } } },
      orderBy: { createdAt: "desc" },
      take: 100
    });

    return NextResponse.json({ items }, { status: 200 });
  } catch (err) {
    // Never throw in route build analysis; return empty response instead
    return NextResponse.json({ items: [], error: "internal" }, { status: 200 });
  }
}