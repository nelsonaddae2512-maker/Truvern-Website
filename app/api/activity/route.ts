async function resolveOrgId(): Promise<number | null> {
  if (devBypassEnabled()) {
    const raw = process.env.TRUVERN_DEV_ORG_ID ?? "";
    const n = Number(raw);
    return Number.isFinite(n) ? n : null;
  }

  const { userId } = auth();
  if (!userId) return null;

  // Pull Clerk profile (email is the best bridge to your DB user table)
  let clerkEmail: string | null = null;
  let clerkName: string | null = null;
  let metaOrgId: number | null = null;
  let metaOrgSlug: string | null = null;

  try {
    const cu = await currentUser();
    clerkEmail = cu?.emailAddresses?.[0]?.emailAddress ?? null;
    clerkName = cu?.fullName ?? null;

    const pm = (cu?.publicMetadata as any) || {};
    const rawOrgId = pm.organizationId ?? pm.orgId ?? null;
    const rawOrgSlug = pm.organizationSlug ?? pm.orgSlug ?? null;

    const n = typeof rawOrgId === "number" ? rawOrgId : Number(rawOrgId ?? "");
    metaOrgId = Number.isFinite(n) ? n : null;
    metaOrgSlug = typeof rawOrgSlug === "string" && rawOrgSlug ? rawOrgSlug : null;
  } catch {
    // ignore; we can still try DB lookups by clerkId
  }

  // If Clerk metadata includes orgId, trust but verify it exists.
  if (metaOrgId) {
    const org = await prisma.organization.findUnique({
      where: { id: metaOrgId },
      select: { id: true },
    });
    if (org) return org.id;
  }

  // 1) Try DB user by clerkId
  let dbUser =
    (await prisma.user.findFirst({
      where: { clerkId: userId },
      select: { id: true, organizationId: true, email: true },
    })) ?? null;

  // 2) If not found, try by email (and attach clerkId)
  if (!dbUser && clerkEmail) {
    const byEmail = await prisma.user.findFirst({
      where: { email: clerkEmail },
      select: { id: true, organizationId: true, email: true },
    });

    if (byEmail) {
      await prisma.user.update({
        where: { id: byEmail.id },
        data: { clerkId: userId, name: clerkName ?? undefined },
      });
      dbUser = byEmail;
    }
  }

  // 3) If still not found, create a DB user row (minimal, safe)
  if (!dbUser && clerkEmail) {
    dbUser = await prisma.user.create({
      data: {
        email: clerkEmail,
        name: clerkName ?? undefined,
        clerkId: userId,
      },
      select: { id: true, organizationId: true, email: true },
    });
  }

  // 4) If Clerk metadata includes orgSlug, resolve it and optionally set user's orgId
  if (dbUser && !dbUser.organizationId && metaOrgSlug) {
    const org = await prisma.organization.findFirst({
      where: { slug: metaOrgSlug },
      select: { id: true },
    });
    if (org) {
      await prisma.user.update({
        where: { id: dbUser.id },
        data: { organizationId: org.id },
      });
      return org.id;
    }
  }

  // 5) Use user's primary organization if set
  if (dbUser?.organizationId) return dbUser.organizationId;

  // 6) Fall back to first membership
  if (dbUser?.id) {
    const mem = await prisma.orgMembership.findFirst({
      where: { userId: dbUser.id },
      select: { organizationId: true },
      orderBy: { createdAt: "asc" as any },
    });
    return mem?.organizationId ?? null;
  }

  return null;
}
