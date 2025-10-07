export const runtime = "nodejs";
export const dynamic = "force-dynamic";
import { NextResponse } from "next/server";
import { getServerSession } from "next-auth";
import { authOptions } from "@/lib/auth";
import { prisma } from "@/lib/prisma";

export async function POST(req: Request){
  const session = await getServerSession(authOptions);
  const me = session?.user as any;
  if(!me?.organizationId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  const { vendorId, questionId, url, note } = await req.json().catch(()=>({}));
  if(!vendorId || !questionId || !url) return NextResponse.json({ error: "vendorId, questionId, url required" }, { status: 400 });

  const vendor = await prisma.vendor.findUnique({ where: { id: String(vendorId) } });
  if(!vendor || vendor.organizationId !== me.organizationId) return NextResponse.json({ error: "Forbidden" }, { status: 403 });

  const row = await prisma.evidence.create({ data: { vendorId: vendor.id, questionId: String(questionId), url: String(url), reviewerNote: note || null, status: "pending" } });
  return NextResponse.json({ ok:true, id: row.id });
}
