import prisma from "@/lib/db";

export const runtime = "nodejs"
export const dynamic = "force-dynamic";
import { NextResponse } from "next/server";import type { NextRequest } from "next/server";

/** Build-time friendly */
export async function GET() {
  return NextResponse.json({ ok: true }, { status: 200 });
}

/**
 * Stripe Webhook: expects raw body + signature header.
 * Env: STRIPE_SECRET_KEY (optional for typed events), STRIPE_WEBHOOK_SECRET (recommended)
 */
export async function POST(req: NextRequest){ const { default: Stripe } = await import("stripe"); 
  try {
    const sig = req.headers.get("stripe-signature") || "";
    const whSecret = process.env.STRIPE_WEBHOOK_SECRET || "";
    const raw = await req.text().catch(() => "");

    // If no secret, don't verify (never crash build/staging)
    let event: any = null;
    if (whSecret && sig && raw) {
      try {
        const { default: Stripe } = await import("stripe");
        const stripe = new Stripe((process.env.STRIPE_SECRET_KEY || process.env.STRIPE_SECRET || "") as string, { apiVersion: "2024-06-20" } as any);
        event = stripe.webhooks.constructEvent(raw, sig, whSecret);
      } catch {
        // Soft-fail: return ok=false but 200 to keep handler resilient
        return NextResponse.json({ ok: false, error: "signature_verification_failed" }, { status: 200 });
      }
    } else {
      // No verification; attempt best-effort parse for local/dev
      try { event = JSON.parse(raw || "{}"); } catch { event = { type: "unknown" }; }
    }

    // Handle a few common event types (no throws)
    const type = String(event?.type || "unknown");
    switch (type) {
      case "checkout.session.completed":
        // TODO: fulfill order / enable subscription
        break;
      case "customer.subscription.updated":
      case "customer.subscription.created":
      case "customer.subscription.deleted":
        // TODO: sync subscription in your DB
        break;
      default:
        // ignore unknowns
        break;
    }

    return NextResponse.json({ ok: true }, { status: 200 });
  } catch {
    // Never throw during build/analyze/runtime
    return NextResponse.json({ ok: false, error: "internal" }, { status: 200 });
  }
}

