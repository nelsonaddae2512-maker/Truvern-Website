import { NextResponse } from "next/server";
import { cookies, headers } from "next/headers";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET() {
  const h = headers();
  const cookieHeader = h.get("cookie") || "";
  const all = cookies().getAll();

  return NextResponse.json({
    ok: true,
    host: h.get("host"),
    hasAnyCookieHeader: cookieHeader.length > 0,
    cookieHeaderLength: cookieHeader.length,
    cookieNames: all.map((c) => c.name),
  });
}
