import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";
export const config = { matcher: ["/api/:path*"] };

export function middleware(req: NextRequest) {
  const url = new URL(req.url);
  const plan = process.env.APP_PLAN || "free";
  const isCsv = url.searchParams.get("format") === "csv";
  const isReport = url.pathname.startsWith("/api/reports/");
  if (plan === "free" && (isCsv || isReport)) {
    return NextResponse.json({ error: "Upgrade required for CSV/export", plan }, { status: 402 });
  }
  return NextResponse.next();
}
