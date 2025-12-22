import { NextResponse } from "next/server";
import prisma from "@/lib/prisma";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

export async function GET(req: Request) {
  const url = new URL(req.url);
  const vendorIdParam = url.searchParams.get("vendorId");
  const takeParam = url.searchParams.get("take");
  const cursorParam = url.searchParams.get("cursor");

  const vendorId = vendorIdParam ? Number(vendorIdParam) : null;
  const take = Math.min(Math.max(Number(takeParam ?? "50"), 1), 200);
  const cursor = cursorParam ? Number(cursorParam) : null;

  // keep your existing logic below...
  const rows = await prisma.evidence.findMany({
    where: vendorId ? { vendorId } : undefined,
    orderBy: [{ createdAt: "desc" }, { id: "desc" }],
    take,
    ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
  });

  return NextResponse.json({ ok: true, evidence: rows });
}
