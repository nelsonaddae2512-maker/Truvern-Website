import { NextResponse } from "next/server";

export async function POST(req: Request) {
  try {
    // temporary placeholder route just to satisfy Vercel build
    return NextResponse.json(
      { status: "ok", message: "upload-file endpoint placeholder working" },
      { status: 200 }
    );
  } catch (err: any) {
    return NextResponse.json(
      { error: "Upload-file temporary route failed", detail: err?.message },
      { status: 500 }
    );
  }
}

export async function GET() {
  return NextResponse.json(
    {
      status: "ok",
      message: "GET /vendor/upload-file placeholder route",
    },
    { status: 200 }
  );
}
