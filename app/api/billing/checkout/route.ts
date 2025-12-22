// app/api/billing/checkout/route.ts
import { NextResponse } from "next/server";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

export async function GET(req: Request) {
  const url = new URL(req.url);
  const plan = url.searchParams.get("plan") || "pro";

  // keep your existing checkout logic...
  return NextResponse.json({ ok: true, plan });
}
