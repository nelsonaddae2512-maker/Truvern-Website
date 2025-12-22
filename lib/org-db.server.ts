import "server-only";

import prisma from "@/lib/prisma";
import { requireOrgContext } from "@/lib/org-guard";

/**
 * SERVER-ONLY: Resolve DB Organization for active Clerk orgId.
 */
export async function requireDbOrganization() {
  const { orgId: clerkOrgId } = requireOrgContext();

  if (!clerkOrgId) throw new Error("Missing Clerk org context");

  const org = await prisma.organization.findFirst({
    where: { clerkOrgId },
    select: { id: true, name: true, clerkOrgId: true },
  });

  if (!org) {
    throw new Error(
      `No DB Organization row found for Clerk orgId=${clerkOrgId}. ` +
        `Provision Organization.clerkOrgId for this org.`
    );
  }

  return org;
}
