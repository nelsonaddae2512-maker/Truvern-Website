import { NextResponse } from "next/server";

export async function GET() {
  const now = new Date().toISOString();
  const vendors = [{ id: 1, name: "Default Vendor" }];
  return NextResponse.json({ generatedAt: now, vendors }, { status: 200 });
}