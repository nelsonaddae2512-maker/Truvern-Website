import { NextResponse } from "next/server";
import { auth } from "@clerk/nextjs/server";

export const runtime = "nodejs";

export async function GET() {
  const { userId, orgId, sessionId } = await auth();

  return NextResponse.json({
    ok: true,
    auth: { userId, orgId, sessionId },
  });
}
