import { NextResponse } from "next/server";

export async function POST(req: Request) {
  const body = await req.json().catch(() => ({}));
  // TODO: wire to email or ticketing
  console.log("Contact form submission:", body);
  return NextResponse.json({ ok: true }, { status: 200 });
}