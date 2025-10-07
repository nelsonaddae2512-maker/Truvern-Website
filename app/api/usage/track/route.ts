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
  const body = await req.json().catch(()=>({}));
  const { type, count=1, vendorId, assessmentId } = body || {};
  if(!type) return NextResponse.json({ error: "type required" }, { status: 400 });
  const row = await prisma.usageEvent.create({ data: {
    organizationId: me.organizationId, type: String(type), count: Number(count)||1,
    vendorId: vendorId ? String(vendorId) : null,
    assessmentId: assessmentId ? String(assessmentId) : null,
  }});
  return NextResponse.json(row, { status: 201 });
}
