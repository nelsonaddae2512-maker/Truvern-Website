// lib/vendor-portal.ts
import "server-only";

import prisma from "@/lib/prisma";
import { auth } from "@clerk/nextjs/server";

export type VendorPortalResolvedContext = {
  userId: string | null;
  selectedClerkOrgId: string | null;

  directLink: any | null;
  directVendor: any | null;
  portalOrg: any | null;

  vendorMatchesOrg: boolean;
  portalOrganizationId: number | null;

  error?: string | null;
};

export async function resolveVendorPortalContext(): Promise<VendorPortalResolvedContext> {
  const a = auth();
  const userId = a.userId ?? null;
  const selectedClerkOrgId = (a.orgId as string | null) ?? null;

  if (!userId) {
    return {
      userId: null,
      selectedClerkOrgId,
      directLink: null,
      directVendor: null,
      portalOrg: null,
      vendorMatchesOrg: false,
      portalOrganizationId: null,
      error: "NOT_SIGNED_IN",
    };
  }

  try {
    const directLink = await prisma.vendorPortalUser.findUnique({
      where: { clerkUserId: userId },
      select: {
        id: true,
        organizationId: true,
        vendorId: true,
        clerkUserId: true,
        createdAt: true,
        updatedAt: true,
      },
    });

    if (!directLink) {
      return {
        userId,
        selectedClerkOrgId,
        directLink: null,
        directVendor: null,
        portalOrg: null,
        vendorMatchesOrg: false,
        portalOrganizationId: null,
        error: "NOT_LINKED",
      };
    }

    const [directVendor, portalOrg] = await Promise.all([
      prisma.vendor.findUnique({
        where: { id: directLink.vendorId },
      }),
      prisma.organization.findUnique({
        where: { id: directLink.organizationId },
      }),
    ]);

    const vendorMatchesOrg =
      !!selectedClerkOrgId &&
      !!portalOrg?.clerkOrgId &&
      selectedClerkOrgId === portalOrg.clerkOrgId;

    return {
      userId,
      selectedClerkOrgId,
      directLink,
      directVendor,
      portalOrg,
      vendorMatchesOrg,
      portalOrganizationId: directLink.organizationId,
      error: null,
    };
  } catch (e: any) {
    return {
      userId,
      selectedClerkOrgId,
      directLink: null,
      directVendor: null,
      portalOrg: null,
      vendorMatchesOrg: false,
      portalOrganizationId: null,
      error: e?.message || "UNKNOWN_ERROR",
    };
  }
}

/**
 * Guard helper for vendor portal routes
 * - NOT_SIGNED_IN → Clerk sign-in (return to /vendor)
 * - NOT_LINKED   → /vendor/not-linked
 */
export async function requireVendorPortalContext() {
  const ctx = await resolveVendorPortalContext();

  // If not signed in, redirect to sign-in and return to /vendor
  if (!ctx.userId) {
    const redirect_url = encodeURIComponent("/vendor");
    return {
      ok: false as const,
      ctx,
      redirectTo: `/sign-in?redirect_url=${redirect_url}`,
    };
  }

  // If signed in but not linked, go to not-linked
  if (!ctx.directLink || !ctx.directVendor || !ctx.portalOrg) {
    return {
      ok: false as const,
      ctx,
      redirectTo: "/vendor/not-linked",
    };
  }

  // Success (org mismatch does NOT block portal)
  return {
    ok: true as const,
    ctx,
    redirectTo: null as string | null,
  };
}
