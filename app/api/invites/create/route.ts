export const runtime = "nodejs";
export const dynamic = "force-dynamic";
import { NextResponse } from "next/server";

// Build-friendly GET for Next's analyzer
export async function GET(){ const { getServerSession } = await import("next-auth"); const { authOptions } = await import("@/lib/auth");  const { prisma } = await import("@/lib/prisma"); 
  try { return NextResponse.json({ ok: true }, { status: 200 }); }
  catch { return NextResponse.json({ ok: false }, { status: 200 }); }
}

// POST { email, organizationId?, role? }
export async function POST(req: Request){ const { getServerSession } = await import("next-auth"); const { authOptions } = await import("@/lib/auth");  const { prisma } = await import("@/lib/prisma"); 
  try {
    // Lazily import next-auth + authOptions INSIDE the handler
    const { getServerSession } = await import("next-auth");
    const { authOptions } = await import("@/lib/auth");
    const session = await getServerSession(authOptions);
    const requester = (session?.user as any)?.email as string | undefined;
    if (!requester) return NextResponse.json({ ok:false, error:"unauthorized" }, { status:200 });

    const body = await req.json().catch(()=>({} as any));
    const email = String(body?.email || "").trim().toLowerCase();
    const organizationId = body?.organizationId ?? null;
    const role = String(body?.role || "member");
    if (!email || !email.includes("@")) {
      return NextResponse.json({ ok:false, error:"invalid_email" }, { status:200 });
    }

    // Lazy prisma import
    const mod = (await import("@/lib/prisma")) as { prisma?: any };
    const prisma = mod?.prisma;
    if (!prisma) return NextResponse.json({ ok:false, error:"prisma_unavailable" }, { status:200 });

    // ensure single active invite
    try { await prisma.pendingInvite.deleteMany({ where: { email, expiresAt: { gt: new Date() } } }); } catch {}

    const token = Math.random().toString(36).slice(2) + Math.random().toString(36).slice(2);
    const expiresAt = new Date(Date.now() + 7*24*60*60*1000);

    const invite = await prisma.pendingInvite.create({
      data: { email, token, organizationId: organizationId as any, role, createdBy: requester, expiresAt },
      select: { id: true }
    });

    // Optional email sender (no destructuring on a union)
    try {
      const mail = (await import("@/lib/email").catch(()=>({}))) as { sendInviteEmail?: (x:any)=>Promise<any> };
      if (typeof mail.sendInviteEmail === "function") await mail.sendInviteEmail({ email, token });
    } catch {}

    return NextResponse.json({ ok:true, inviteId: invite.id }, { status:200 });
  } catch {
    // never throw during build analysis
    return NextResponse.json({ ok:false, error:"internal" }, { status:200 });
  }
}