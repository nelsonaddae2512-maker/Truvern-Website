import { NextResponse } from "next/server";
import { auth } from "@clerk/nextjs/server";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET() {
  const a = auth();

  const hasPublishable = !!process.env.NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY;
  const hasSecret = !!process.env.CLERK_SECRET_KEY;

  // If secret key is missing, server auth will usually appear "signed out"
  const reason =
    !hasPublishable ? "MISSING_PUBLISHABLE_KEY" :
    !hasSecret ? "MISSING_SECRET_KEY" :
    !a.userId ? "NO_USER_SESSION" :
    !a.orgId ? "NO_ORG_SELECTED" :
    null;

  return NextResponse.json({
    ok: true,
    auth: {
      userId: a.userId ?? null,
      orgId: a.orgId ?? null,
      sessionId: a.sessionId ?? null,
    },
    env: {
      hasPublishable,
      hasSecret,
    },
    needsOrgSelection: !!a.userId && !a.orgId,
    reason,
  });
}
