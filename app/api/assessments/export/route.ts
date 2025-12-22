// app/api/assessments/export/route.ts
import { NextResponse } from "next/server";
import prisma from "@/lib/prisma";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

export async function GET(req: Request) {
  const url = new URL(req.url);
  const vendorIdParam = url.searchParams.get("vendorId");

  const vendorId = vendorIdParam ? Number(vendorIdParam) : null;

  // ✅ keep the rest of your existing file logic here...
  // (query prisma, build CSV, return response)
  return NextResponse.json({ ok: false, error: "not implemented in this patch" }, { status: 501 });
}
