export const runtime = 'nodejs';
import { NextResponse } from "next/server";

export async function GET() {
  const plan = process.env.APP_PLAN ?? "free";
  if (plan === "pro" || plan === "enterprise") {
    return NextResponse.json({ ok: true, plan, data: { widgets: 7, reports: 3 } }, { status: 200, headers: { "Cache-Control": "no-store" } });
  }
  return NextResponse.json({ error: "Payment Required", plan }, { status: 402, headers: { "Cache-Control": "no-store" } });
}