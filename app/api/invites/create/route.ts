export const runtime = "nodejs";
export const dynamic = "force-dynamic";

import { NextResponse } from "next/server";
import { getServerSession } from "next-auth";
import { authOptions } from "@/lib/auth";

// Build-time friendly GET (used by Next's "collect page data")
export async function GET() {
  try {
    return NextResponse.json({ ok: true }, { status: 200 });
  } catch {
    return NextResponse.json({ ok: false }, { status: 200 });
  }
}

// Create invite via POST { email, organizationId?, role? }
export async function POST(req: Request) {
  try {
    const session = await getServerSession(authOptions);
    const requester = (session?.user as any)?.email as string | undefined;
    if (!requester) return NextResponse.json({ ok: false, error: "unauthorized" }, { status: 200 });

    const body = await req.json().catch(() => ({} as any));
    const email = String(body?.email || "").trim().toLowerCase();
    const organizationId = body?.organizationId ?? null;
    const role = String(body?.role || "member");

    if (!email || !email.includes("@")) {
      return NextResponse.json({ ok: false, error: "invalid_email" }, { status: 200 });
    }

    // Lazy import prisma at request time (prevents build-time init)
    const mod = (await import("@/lib/prisma")) as { prisma?: any };
    const prisma = mod?.prisma;
    if (!prisma) return NextResponse.json({ ok: false, error: "prisma_unavailable" }, { status: 200 });

    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000); // 7 days
    const token = Math.random().toString(36).slice(2) + Math.random().toString(36).slice(2);

    // Clean existing active invites for same email
    try { await prisma.pendingInvite.deleteMany({ where: { email, expiresAt: { gt: new Date() } } }); } catch {}

    const invite = await prisma.pendingInvite.create({
      data: { email, token, organizationId: organizationId as any, role, createdBy: requester, expiresAt }
    });

    // Optional email (safe, no type errors)
    try {
      const emailMod = (await import("@/lib/email").catch(() => ({}))) as { sendInviteEmail?: (x:any)=>Promise<any> };
      if (typeof emailMod.sendInviteEmail === "function") {
        await emailMod.sendInviteEmail({ email, token });
      }
    } catch {}

    return NextResponse.json({ ok: true, inviteId: invite.id }, { status: 200 });
  } catch {
    return NextResponse.json({ ok: false, error: "internal" }, { status: 200 });
  }
}