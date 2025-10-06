
import { NextResponse } from "next/server";
import { verifyInviteToken } from "@/lib/invite";
import { prisma } from "@/lib/prisma";

export async function GET(_: Request, { params }: { params: { token: string } }){
  const data = verifyInviteToken(params.token);
  if(!data) return NextResponse.json({ error: "Invalid or expired invite" }, { status: 400 });

  const expiresAt = new Date(data.exp * 1000);
  await prisma.pendingInvite.upsert({
    where: { email: data.email.toLowerCase() },
    update: { organizationId: data.organizationId, role: data.role, expiresAt },
    create: { email: data.email.toLowerCase(), organizationId: data.organizationId, role: data.role, expiresAt }
  });

  return NextResponse.json({ ok: true, email: data.email, organizationId: data.organizationId, role: data.role });
}
