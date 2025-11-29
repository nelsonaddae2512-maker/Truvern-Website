export const runtime = 'nodejs';
import { NextResponse } from "next/server";

export async function GET() {
  const plan = process.env.APP_PLAN ?? "free";
  const org  = process.env.APP_ORG_NAME ?? "demo";
  const maxVendors = plan === "free" ? 3 : plan === "pro" ? 100 : 10000;
  return NextResponse.json({ plan, org, caps: { vendors: maxVendors } }, { status: 200, headers: { "Cache-Control": "no-store" } });
}