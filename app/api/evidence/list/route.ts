export const runtime = "nodejs";
export const dynamic = "force-dynamic";
import { NextResponse } from "next/server";

export async function GET() {
  try {
    // Return a shape that wonÃ¢â‚¬â„¢t blow up during build-time analysis
    return NextResponse.json({ items: [] }, { status: 200 });
  } catch {
    // Never throw from here in build analysis
    return NextResponse.json({ items: [], error: "internal" }, { status: 200 });
  }
}

