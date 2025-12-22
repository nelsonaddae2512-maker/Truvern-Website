// app/api/search/vendors/route.ts
import { NextResponse } from "next/server";
import prisma from "@/lib/prisma";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

export async function GET(req: Request) {
  const url = new URL(req.url);
  const q = (url.searchParams.get("q") ?? "").trim();
  const takeParam = url.searchParams.get("take");
  const take = Math.min(Math.max(Number(takeParam ?? "20"), 1), 200);

  const vendors = await prisma.vendor.findMany({
    where: q
      ? {
          OR: [
            { name: { contains: q, mode: "insensitive" } },
            // remove these if your schema doesn't have them:
            { category: { contains: q, mode: "insensitive" } as any },
            { contactEmail: { contains: q, mode: "insensitive" } as any },
          ],
        }
      : undefined,
    orderBy: [{ updatedAt: "desc" }, { id: "desc" }],
    take,
    select: { id: true, name: true },
  });

  return NextResponse.json({ ok: true, vendors });
}
