import prisma from "@/lib/db";

export const runtime = "nodejs"
export const dynamic = "force-dynamic";
import { NextResponse } from "next/server";import type { NextRequest } from "next/server";

/** Build-time friendly GET */
export async function GET() {
  return NextResponse.json({ ok: true }, { status: 200 });
}

/**
 * POST body (examples):
 * { "customerId": "cus_123", "returnUrl": "https://example.com/account" }
 * OR
 * { "customerEmail": "buyer@example.com", "returnUrl": "https://example.com/account" }
 */
export async function POST(req: NextRequest){ const { default: Stripe } = await import("stripe"); 
  try {
    const body = await req.json().catch(() => ({} as any));
    const secret = process.env.STRIPE_SECRET_KEY || process.env.STRIPE_SECRET || "";
    if (!secret) {
      return NextResponse.json({ ok: false, error: "stripe_key_missing" }, { status: 200 });
    }

    // Lazy import Stripe at request time
    const { default: Stripe } = await import("stripe");
    const stripe = new Stripe(secret as string, { apiVersion: "2024-06-20" } as any);

    let customerId: string | undefined = typeof body.customerId === "string" ? body.customerId : undefined;
    const returnUrl = String(body.returnUrl || process.env.PORTAL_RETURN_URL || "https://example.com/account");

    // Optionally look up customer by email (soft-fail)
    if (!customerId && typeof body.customerEmail === "string" && body.customerEmail.includes("@")) {
      try {
        const customers = await stripe.customers.list({ email: body.customerEmail, limit: 1 });
        customerId = customers.data[0]?.id;
      } catch { /* ignore */ }
    }

    if (!customerId) {
      return NextResponse.json({ ok: false, error: "missing_customer" }, { status: 200 });
    }

    const session = await stripe.billingPortal.sessions.create({
      customer: customerId,
      return_url: returnUrl
    });

    return NextResponse.json({ ok: true, url: session.url }, { status: 200 });
  } catch {
    return NextResponse.json({ ok: false, error: "internal" }, { status: 200 });
  }
}

