export const runtime = "nodejs";

import { NextResponse } from "next/server";
import { getServerSession } from "next-auth";
import { authOptions } from "@/lib/auth";
import { prisma } from "@/lib/prisma";
import { createInviteToken } from "@/lib/invite";
import { Resend } from "resend";

export async function POST(req: Request){
  const session = await getServerSession(authOptions);
  const me = session?.user as any;
  if(!me?.organizationId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  const { email, role='MEMBER' } = await req.json().catch(()=>({}));
  if(!email) return NextResponse.json({ error: "email required" }, { status: 400 });
  const org = await prisma.organization.findUnique({ where: { id: me.organizationId } });
  if(!org) return NextResponse.json({ error: "Org not found" }, { status: 404 });
  if(!['OWNER','ADMIN','MEMBER'].includes(role)) return NextResponse.json({ error: "invalid role" }, { status: 400 });

  const { token } = createInviteToken(email, org.id, role);
  const base = process.env.NEXTAUTH_URL || 'http://localhost:3000';
  const url = `${base}/invite/${token}`;

  const ttlDays = Number(process.env.INVITE_TTL_DAYS || '7');
  const expiresAt = new Date(Date.now() + ttlDays*24*60*60*1000);
  await prisma.pendingInvite.upsert({
    where: { email: email.toLowerCase() },
    update: { organizationId: org.id, role, expiresAt },
    create: { email: email.toLowerCase(), organizationId: org.id, role, expiresAt }
  });

  try{
    if(process.env.RESEND_API_KEY && process.env.EMAIL_FROM){
      const resend = new Resend(process.env.RESEND_API_KEY);
      await resend.emails.send({
        from: process.env.EMAIL_FROM!,
        to: email,
        subject: "You're invited to Truvern",
        html: `<p>You have been invited to join <b>${org.name}</b> on Truvern.</p><p><a href="${url}">Accept invite</a></p>`
      });
    }
  }catch(e){ console.error('Invite email failed', e); }

  return NextResponse.json({ url });
}
