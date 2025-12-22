import { NextResponse } from "next/server";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

export async function GET(req: Request) {
  const url = new URL(req.url);
  const cid = url.searchParams.get("cid");

  // keep your existing portal logic...
  return NextResponse.json({ ok: true, cid });
}
