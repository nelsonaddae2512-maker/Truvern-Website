export const runtime = "nodejs";
export const dynamic = "force-dynamic";
import { NextResponse } from "next/server";

export async function POST(req: Request){ const { getServerSession } = await import("next-auth"); const { authOptions } = await import("@/lib/auth");  const { prisma } = await import("@/lib/prisma"); 
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

import { NextResponse } from "next/server";
export async function GET(){ return NextResponse.json({ ok:true }, { status:200 }); }
