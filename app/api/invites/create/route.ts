export const runtime = "nodejs";
export const dynamic = "force-dynamic";

import { NextResponse } from "next/server";
import { getServerSession } from "next-auth";
import { authOptions } from "@/lib/auth";

// Minimal GET that never throws (helps Next collect page data)
export async function GET() {
  try {
    return NextResponse.json({ ok: true }, { status: 200 });
  } catch {
    return NextResponse.json({ ok: false }, { status: 200 });
  }
}

// Create a pending invite via POST { email, organizationId?, role? }
export async function POST(req: Request) {
  try {
    const session = await getServerSession(authOptions);
    const requester = (session?.user as any)?.email as string | undefined;
    if (!requester) return NextResponse.json({ ok: false, error: "unauthorized" }, { status: 200 });

    const body = await req.json().catch(() => ({}));
    const email = String(body?.email || "").trim().toLowerCase();
    const organizationId = body?.organizationId ?? null;
    const role = String(body?.role || "member");

    // Basic validation
    if (!email || !email.includes("@")) {
      return NextResponse.json({ ok: false, error: "invalid_email" }, { status: 200 });
    }

    // Lazy import prisma only at request time (avoids build-time side effects)
    const { prisma } = await import("@/lib/prisma");

    const expiresAt = new Date(Date.now() + 1000 * 60 * 60 * 24 * 7); // 7 days
    const token = Math.random().toString(36).slice(2) + Math.random().toString(36).slice(2);

    // Upsert-ish: delete any existing non-expired invite for same email to keep it simple
    try {
      await prisma.pendingInvite.deleteMany({ where: { email, expiresAt: { gt: new Date() } } });
    } catch {}

    const invite = await prisma.pendingInvite.create({
      data: {
        email,
        token,
        organizationId: organizationId as any,
        role,
        createdBy: requester,
        expiresAt
      }
    });

    // Optional: if you have a mailer wired, trigger it here (soft-fail)
    try {
      const { sendInviteEmail } = await import("@/lib/email").catch(() => ({ sendInviteEmail: null as any }));
      if (typeof sendInviteEmail === "function") {
        await sendInviteEmail({ email, token });
      }
    } catch {}

    return NextResponse.json({ ok: true, inviteId: invite.id }, { status: 200 });
  } catch {
    // Never throw during build analysis
    return NextResponse.json({ ok: false, error: "internal" }, { status: 200 });
  }
}