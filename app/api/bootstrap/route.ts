import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";
import { getAuth } from "@clerk/nextjs/server";
import prisma from "@/lib/prisma";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

function slugify(input: string) {
  return input
    .toLowerCase()
    .trim()
    .replace(/['"]/g, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 48);
}

export async function GET(req: NextRequest) {
  const { userId, orgId } = getAuth(req);

  if (!userId) {
    return NextResponse.json({ ok: false, error: "Not signed in" }, { status: 401 });
  }

  // 1) Ensure DB user exists with clerkId
  let dbUser = await prisma.user.findFirst({ where: { clerkId: userId } });

  if (!dbUser) {
    // deterministic unique email for dev, avoids collisions
    const email = `dev+${userId}@local`;
    dbUser = await prisma.user.create({
      data: {
        email,
        name: "Dev User",
        clerkId: userId,
      },
    });
  }

  // 2) Find or create org
  let org = null as any;

  // Prefer mapping by clerkOrgId if present
  if (orgId) {
    org = await prisma.organization.findFirst({ where: { clerkOrgId: orgId } });
  }

  // Fallback: user's primary org
  if (!org && dbUser.organizationId) {
    org = await prisma.organization.findUnique({ where: { id: dbUser.organizationId } });
  }

  // Fallback: first org
  if (!org) {
    org = await prisma.organization.findFirst({ orderBy: { id: "asc" } });
  }

  // Create if none exists
  if (!org) {
    const baseName = "Truvern Demo Org";
    const baseSlug = slugify(baseName) || "truvern-demo";
    let slug = baseSlug;

    for (let i = 0; i < 50; i++) {
      const exists = await prisma.organization.findFirst({ where: { slug } });
      if (!exists) break;
      slug = `${baseSlug}-${i + 2}`;
    }

    org = await prisma.organization.create({
      data: {
        name: baseName,
        slug,
        clerkOrgId: orgId ?? null,
      },
    });
  } else {
    // If we have an orgId and org isn't linked, link it
    if (orgId && !org.clerkOrgId) {
      org = await prisma.organization.update({
        where: { id: org.id },
        data: { clerkOrgId: orgId },
      });
    }
  }

  // 3) Ensure membership exists
  await prisma.orgMembership.upsert({
    where: {
      userId_organizationId: { userId: dbUser.id, organizationId: org.id },
    },
    update: {},
    create: {
      userId: dbUser.id,
      organizationId: org.id,
      role: "OWNER",
    },
  });

  // 4) Set primary organizationId on user
  if (dbUser.organizationId !== org.id) {
    dbUser = await prisma.user.update({
      where: { id: dbUser.id },
      data: { organizationId: org.id },
    });
  }

  return NextResponse.json({
    ok: true,
    clerk: { userId, orgId: orgId ?? null },
    db: { userId: dbUser.id, organizationId: org.id, orgSlug: org.slug },
  });
}
