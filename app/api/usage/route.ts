export const runtime = 'nodejs';
import { NextResponse } from "next/server";

export async function GET() {
  const plan = process.env.APP_PLAN || "free";
  const vendors = Number(process.env.USAGE_VENDORS || 0);
  const members = Number(process.env.USAGE_MEMBERS || 0);
  const assessments = Number(process.env.USAGE_ASSESSMENTS || 0);

  return NextResponse.json({
    ok: true,
    usage: [
      { key: "plan", value: plan },
      { key: "vendors", value: vendors },
      { key: "members", value: members },
      { key: "assessments", value: assessments }
    ]
  });
}