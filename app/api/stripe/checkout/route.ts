export const runtime = "nodejs";
export const dynamic = "force-dynamic";
import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

/** Build-time friendly */
export async function GET() {
  return NextResponse.json({ ok: true }, { status: 200 });
}

/**
 * POST body (example):
 * {
 *   "mode": "subscription",
 *   "priceId": "price_123",
 *   "successUrl": "https://example.com/success",
 *   "cancelUrl": "https://example.com/cancel",
 *   "customerEmail": "buyer@example.com",
 *   "metadata": { "vendorId": "v_abc" }
 * }
 */
export async function POST(req: NextRequest){ const { default: Stripe } = await import("stripe"); 
  try {
    const body = await req.json().catch(() => ({} as any));
    const secret = process.env.STRIPE_SECRET_KEY || process.env.STRIPE_SECRET || "";
    if (!secret) {
      // DonÃ¢â‚¬â„¢t throw during build; return a helpful message
      return NextResponse.json({ ok: false, error: "stripe_key_missing" }, { status: 200 });
    }

    // Lazy import stripe only at request time (prevents build-time failures)
    const { default: Stripe } = await import("stripe");
    // Pin an API version that's compatible with your installed stripe package
    const stripe = new Stripe(secret as string, { apiVersion: "2024-06-20" } as any);

    const mode = (body.mode === "payment" ? "payment" : "subscription") as "payment" | "subscription";
    const priceId = String(body.priceId || "");
    const successUrl = String(body.successUrl || process.env.CHECKOUT_SUCCESS_URL || "https://example.com/success");
    const cancelUrl  = String(body.cancelUrl  || process.env.CHECKOUT_CANCEL_URL  || "https://example.com/cancel");
    const customerEmail = typeof body.customerEmail === "string" ? body.customerEmail : undefined;
    const metadata = (body.metadata && typeof body.metadata === "object") ? body.metadata : undefined;

    if (!priceId) {
      return NextResponse.json({ ok: false, error: "missing_priceId" }, { status: 200 });
    }

    const params: any = {
      mode,
      success_url: successUrl,
      cancel_url: cancelUrl,
      allow_promotion_codes: true,
      metadata,
      line_items: [{ price: priceId, quantity: 1 }]
    };
    if (customerEmail) params.customer_email = customerEmail;

    const session = await stripe.checkout.sessions.create(params);

    return NextResponse.json({ ok: true, id: session.id, url: session.url }, { status: 200 });
  } catch {
    // Never crash build; keep errors soft
    return NextResponse.json({ ok: false, error: "internal" }, { status: 200 });
  }
}

