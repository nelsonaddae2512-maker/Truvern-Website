export const runtime = "nodejs";
export const dynamic = "force-dynamic";

import type { NextRequest } from "next/server";

async function getHandler() {
  const { default: NextAuth } = await import("next-auth");
  // Lazy import authOptions to avoid work during build-time analysis
  const { authOptions } = await import("@/lib/auth");
  return NextAuth(authOptions);
}

export async function GET(req: NextRequest, ctx: any) {
  const handler = await getHandler();
  // @ts-ignore – handler signature is compatible
  return handler(req as any, ctx as any);
}

export async function POST(req: NextRequest, ctx: any) {
  const handler = await getHandler();
  // @ts-ignore – handler signature is compatible
  return handler(req as any, ctx as any);
}