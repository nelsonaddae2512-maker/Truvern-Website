import { NextResponse } from "next/server";

export async function GET() {
  return NextResponse.json(
    {
      status: "ok",
      message: "GET /trust/embed placeholder route",
    },
    { status: 200 }
  );
}

export async function POST(req: Request) {
  try {
    // Minimal placeholder, replace with real logic later if needed
    return NextResponse.json(
      {
        status: "ok",
        message: "POST /trust/embed placeholder working",
      },
      { status: 200 }
    );
  } catch (err: any) {
    return NextResponse.json(
      {
        status: "error",
        message: "POST /trust/embed failed",
        detail: err?.message ?? "unknown error",
      },
      { status: 500 }
    );
  }
}
