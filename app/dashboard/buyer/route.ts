import { NextResponse } from "next/server";

export async function GET() {
  return NextResponse.json(
    {
      status: "ok",
      message: "GET /dashboard/buyer placeholder route",
    },
    { status: 200 }
  );
}

export async function POST(req: Request) {
  return NextResponse.json(
    {
      status: "ok",
      message: "POST /dashboard/buyer placeholder route",
    },
    { status: 200 }
  );
}
