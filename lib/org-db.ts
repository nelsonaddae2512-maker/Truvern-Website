// lib/org-db.ts
import { auth } from "@clerk/nextjs/server";
import prisma from "@/lib/prisma";

type DbOrg = {
  id: number;
  name: string;
  slug: string;
  clerkOrgId: string | null;
};

export async function requireDbOrganization(): Promise<
  DbOrg | { _needsOrgSelection: true }
> {
  const { userId, orgId } = await auth();

  // Not signed in
  if (!userId) {
    return { _needsOrgSelection: true };
  }

  // Signed in but no active Clerk org
  if (!orgId) {
    return { _needsOrgSelection: true };
  }

  // 1️⃣ Try to find existing DB org
  const existing = await prisma.organization.findFirst({
    where: { clerkOrgId: orgId },
    select: { id: true, name: true, slug: true, clerkOrgId: true },
  });

  if (existing) {
    return existing;
  }

  // 2️⃣ Auto-create DB org if missing
  const slugBase = `org-${orgId
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .slice(0, 40)}`;

  const slug =
    (await prisma.organization.findFirst({ where: { slug: slugBase } }))
      ? `${slugBase}-${Date.now().toString().slice(-5)}`
      : slugBase;

  const created = await prisma.organization.create({
    data: {
      clerkOrgId: orgId,
      name: "Organization",
      slug,
    },
    select: { id: true, name: true, slug: true, clerkOrgId: true },
  });

  return created;
}
