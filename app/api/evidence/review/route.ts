
import { NextResponse } from "next/server";
import { getServerSession } from "next-auth";
import { authOptions } from "@/lib/auth";
import { prisma } from "@/lib/prisma";

export async function POST(req: Request){
  const session = await getServerSession(authOptions);
  const me = session?.user as any;
  if(!me?.email) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  const { id, status, note } = await req.json().catch(()=>({}));
  if(!id || !['approved','rejected','pending'].includes(String(status))) return NextResponse.json({ error: "id & valid status required" }, { status: 400 });
  const ev = await prisma.evidence.findUnique({ where: { id: String(id) } });
  if(!ev) return NextResponse.json({ error: "Not found" }, { status: 404 });
  // Simple org enforcement: reviewer must be in same org as vendor
  const vendor = await prisma.vendor.findUnique({ where: { id: ev.vendorId } });
  if(!vendor) return NextResponse.json({ error: "Vendor missing" }, { status: 404 });
  const mem = await prisma.membership.findFirst({ where: { user: { email: me.email }, organizationId: vendor.organizationId } });
  if(!mem) return NextResponse.json({ error: "Forbidden" }, { status: 403 });
  const updated = await prisma.evidence.update({ where: { id: ev.id }, data: { status: String(status), reviewerNote: note || null } });
  return NextResponse.json({ ok: true, evidence: updated });
}
