import { NextResponse } from "next/server";
export const runtime = "nodejs";

// GET /api/stripe/portal?cid=cus_123
export async function GET(req: Request) {
  try {
    const secret = process.env.STRIPE_SECRET_KEY;
    const appUrl = process.env.APP_URL ?? "https://truvern.com";
    if (!secret) {
      return NextResponse.json(
        { ok: false, reason: "Stripe not configured: missing STRIPE_SECRET_KEY.", go: `${appUrl}/account/billing` },
        { status: 200 }
      );
    }

    const { searchParams } = new URL(req.url);
    const cid = searchParams.get("cid"); // Stripe customer id
    if (!cid) {
      return NextResponse.json({ ok: false, reason: "Missing ?cid=StripeCustomerId" }, { status: 200 });
    }

    const Stripe = (await import("stripe")).default;
    const stripe = new Stripe(secret, { apiVersion: "2023-10-16" });

    const session = await stripe.billingPortal.sessions.create({
      customer: cid,
      return_url: `${appUrl}/account/billing`
    });
    return NextResponse.json({ ok: true, url: session.url }, { status: 200 });
  } catch (err: any) {
    return NextResponse.json({ ok: false, error: err?.message ?? String(err) }, { status: 200 });
  }
}