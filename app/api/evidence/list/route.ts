import prisma from "@/lib/db";

import { NextResponse } from "next/server";import type { Session } from "next-auth";
import { getServerSession } from "next-auth";
import { authOptions } from "../../../../src/lib/auth"
export async function GET() {
  type SessionWithId = Session & { user: { id: string } }; const session = (await getServerSession(authOptions)) as SessionWithId | null;
  if (!session?.user?.id) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }
  const items = await prisma.evidence.findMany({
    where: { userId: (session.user as any).id },
    orderBy: { createdAt: "desc" },
    take: 100,
  });
  return NextResponse.json({ items });
}

