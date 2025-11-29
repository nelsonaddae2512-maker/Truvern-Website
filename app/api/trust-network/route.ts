import { NextResponse } from "next/server";

export async function GET() {
  const items = [
    { id: 1, name: "Default Vendor", score: "A" },
    { id: 2, name: "Sample Partner", score: "B+" }
  ];
  return NextResponse.json({ vendors: items }, { status: 200 });
}