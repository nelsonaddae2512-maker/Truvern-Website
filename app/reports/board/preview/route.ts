import { NextResponse } from "next/server";

export async function GET() {
  // Minimal placeholder so Vercel can create a lambda for /reports/board/preview
  return NextResponse.json(
    {
      status: "ok",
      route: "/reports/board/preview",
      message: "Board preview placeholder route",
    },
    { status: 200 }
  );
}

export async function POST(req: Request) {
  try {
    // You can later accept JSON to generate a preview, etc.
    const body = await req.json().catch(() => null);

    return NextResponse.json(
      {
        status: "ok",
        route: "/reports/board/preview",
        received: body ?? null,
        message: "POST board preview placeholder route",
      },
      { status: 200 }
    );
  } catch (err: any) {
    return NextResponse.json(
      {
        status: "error",
        message: "Board preview placeholder failed",
        detail: err?.message ?? "unknown error",
      },
      { status: 500 }
    );
  }
}
