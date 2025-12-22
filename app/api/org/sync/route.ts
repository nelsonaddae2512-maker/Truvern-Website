import { NextResponse } from "next/server";
import prisma from "@/lib/prisma";
import { auth, clerkClient } from "@clerk/nextjs/server";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function POST() {
  const { userId, orgId } = await auth();
  if (!userId) {
    return NextResponse.json({ ok: false, error: "Not signed in" }, { status: 401 });
  }
  if (!orgId) {
    return NextResponse.json({ ok: false, error: "No active org" }, { status: 400 });
  }

  // Fetch org name from Clerk (best-effort)
  let orgName: string | null = null;
  try {
    const org = await (await clerkClient()).organizations.getOrganization({ organizationId: orgId });
    orgName = org?.name ?? null;
  } catch {
    orgName = null;
  }

  // Upsert Organization row by clerkOrgId
  const existing = await prisma.organization.findFirst({
    where: { clerkOrgId: orgId } as any,
    select: { id: true } as any,
  });

  if (existing?.id) {
    return NextResponse.json({ ok: true, dbOrgId: existing.id, clerkOrgId: orgId, name: orgName });
  }

  // Create new org row (minimal fields)
  const created = await prisma.organization.create({
    data: {
      name: orgName || "Organization",
      clerkOrgId: orgId,
    } as any,
    select: { id: true, name: true } as any,
  });

  return NextResponse.json({ ok: true, dbOrgId: created.id, clerkOrgId: orgId, name: created.name });
}
