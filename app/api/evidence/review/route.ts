import { NextResponse } from "next/server";
import { getServerSession } from "next-auth";
import { authOptions } from "@/lib/auth";

// Review queue for the signed-in reviewer (evidence awaiting review)
export async function GET() {
  try {
    const session = await getServerSession(authOptions);
    const email = (session?.user as any)?.email as string | undefined;
    if (!email) return NextResponse.json({ items: [] }, { status: 200 });

    // Lazy import prisma to avoid build-time side effects
    const { prisma } = await import("@/lib/prisma");

    // Find orgs this reviewer belongs to
    const memberships = await prisma.membership.findMany({
      where: { user: { email } },
      select: { organizationId: true },
    });
    const orgIds = memberships.map((m: { organizationId: string | number }) => m.organizationId);
    if (orgIds.length === 0) return NextResponse.json({ items: [] }, { status: 200 });

    // Evidence awaiting review for vendors in those orgs
    const items = await prisma.evidence.findMany({
      where: {
        vendor: { organizationId: { in: orgIds as any[] } },
        status: { in: ["submitted", "in-review"] },
      },
      orderBy: { updatedAt: "desc" },
      take: 100,
    });

    return NextResponse.json({ items }, { status: 200 });
  } catch (err) {
    // Never throw during build analysis
    return NextResponse.json({ items: [], error: "internal" }, { status: 200 });
  }
}

// Optionally accept POST updates to mark evidence reviewed (safe no-op if you haven't wired it)
export async function POST(req: Request) {
  try {
    const { prisma } = await import("@/lib/prisma");
    const body = await req.json().catch(() => ({}));
    const id = body?.id as string | undefined;
    const action = body?.action as "approve" | "reject" | undefined;
    if (!id || !action) return NextResponse.json({ ok: false }, { status: 200 });

    await prisma.evidence.update({
      where: { id },
      data: {
        status: action === "approve" ? "approved" : "rejected",
        reviewedAt: new Date(),
      },
    });
    return NextResponse.json({ ok: true }, { status: 200 });
  } catch {
    return NextResponse.json({ ok: false }, { status: 200 });
  }
}