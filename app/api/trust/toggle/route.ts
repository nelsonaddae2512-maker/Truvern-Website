export const runtime = "nodejs";
export const dynamic = "force-dynamic";
import { NextResponse } from "next/server";
import { getServerSession } from "next-auth";
import { authOptions } from "@/lib/auth";

import crypto from "crypto";
import { notifyTrustChange } from "@/lib/notify";

export async function POST(req: Request){ const { prisma } = await import("@/lib/prisma"); 
  const session = await getServerSession(authOptions);
  const me = session?.user as any;
  if(!me?.organizationId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  const { vendorId, public:makePublic } = await req.json();
  const vendor = await prisma.vendor.findUnique({ where: { id: String(vendorId) } });
  if(!vendor || vendor.organizationId !== me.organizationId) return NextResponse.json({ error:"Forbidden" }, { status: 403 });
  const trustToken = makePublic ? (vendor.trustToken || crypto.randomBytes(8).toString("hex")) : null;
  const updated = await prisma.vendor.update({ where: { id: vendor.id }, data: { trustPublic: !!makePublic, trustToken } });
  const publicUrl = updated.trustPublic ? `${process.env.NEXTAUTH_URL || "http://localhost:3000"}/trust/${updated.slug}` : null;
  await notifyTrustChange({ name: vendor.name, slug: vendor.slug, publicUrl, action: updated.trustPublic ? 'published' : 'unpublished' });
  return NextResponse.json({ ok:true, slug: updated.slug, publicUrl, badgeUrl: updated.trustPublic && trustToken ? `${process.env.NEXTAUTH_URL || "http://localhost:3000"}/api/trust/badge?slug=${updated.slug}&t=${trustToken}` : null });
}
