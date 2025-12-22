// lib/org-db.ts
import { auth } from "@clerk/nextjs/server";
import prisma from "@/lib/prisma";

/**
 * requireDbOrganization()
 * - Returns the DB Organization row for the active Clerk org.
 * - If user is signed in but no Clerk org is selected, returns {_needsOrgSelection: true}
 * - If Clerk org is selected but DB org doesn't exist yet, it creates one.
 */
export async function requireDbOrganization(): Promise<
  | { id: number; name: string; slug: string; clerkOrgId: string | null }
  | { _needsOrgSelection: true; userId: string }
> {
  const a = auth();
  const userId = a.userId || null;
  const clerkOrgId = a.orgId || null;

  if (!userId) {
    // Let upstream middleware / Clerk protect handle this; but return needs selection-ish shape
    return { _needsOrgSelection: true, userId: "signed-out" };
  }

  // Signed in but no active org
  if (!clerkOrgId) {
    return { _needsOrgSelection: true, userId };
  }

  // 1) Try exact match on clerkOrgId
  const existing = await prisma.organization.findFirst({
    where: { clerkOrgId },
    select: { id: true, name: true, slug: true, clerkOrgId: true },
  });

  if (existing) return existing;

  // 2) Create a DB org row if missing
  // We don't have Clerk org name here without extra API calls, so create a stable placeholder.
  // You can later add a sync job to keep names in sync if you want.
  const slug = `org-${clerkOrgId.toLowerCase().replace(/[^a-z0-9]+/g, "-").slice(0, 40)}`;

  // Ensure slug uniqueness (rare but safe)
  const taken = await prisma.organization.findFirst({
    where: { slug },
    select: { id: true },
  });

  const finalSlug = taken ? `${slug}-${Date.now().toString().slice(-6)}` : slug;

  const created = await prisma.organization.create({
    data: {
      clerkOrgId,
      name: "Organization",
      slug: finalSlug,
    },
    select: { id: true, name: true, slug: true, clerkOrgId: true },
  });

  return created;
}
