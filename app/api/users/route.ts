// app/api/users/route.ts
import { NextResponse } from "next/server";
import prisma from "@/lib/prisma";

export const runtime = "nodejs";

export async function GET() {
  const users = await prisma.user.findMany({
    select: { id: true, name: true, email: true },
    orderBy: { id: "asc" },
    take: 200,
  });

  return NextResponse.json({ ok: true, users });
}
