import { NextRequest, NextResponse } from "next/server";

export const runtime = "nodejs";

export async function POST(req: NextRequest) {
  const contentType = req.headers.get("content-type") || "";

  if (!contentType.includes("multipart/form-data"))
    return NextResponse.json({ error: "Expected multipart/form-data" }, { status: 400 });

  await req.blob().catch(() => null);

  return NextResponse.json(
    {
      ok: true,
      message: "Upload stub reached — file not stored yet.",
    },
    { status: 200 }
  );
}
