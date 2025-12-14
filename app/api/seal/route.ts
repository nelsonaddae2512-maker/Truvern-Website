// app/api/seal/route.ts
import { NextResponse } from "next/server";

export const runtime = "nodejs";

export async function GET() {
  // Production-ready: use env (set by your deploy pipeline) or fallback to short “Verified”.
  const hash =
    process.env.VERCEL_GIT_COMMIT_SHA ||
    process.env.NEXT_PUBLIC_BUILD_SHA ||
    process.env.BUILD_SHA ||
    "";

  const short = hash ? `Verified • ${hash.slice(0, 7)}` : "Verified";

  return NextResponse.json({
    ok: true,
    short,
    hash: hash || undefined,
    ts: new Date().toISOString(),
  });
}
