import { NextResponse } from "next/server";
export const runtime = "nodejs";

export async function POST(req: Request) {
  try {
    const secret = process.env.STRIPE_SECRET_KEY;
    const appUrl = process.env.APP_URL ?? "https://truvern.com";
    if (!secret) {
      return NextResponse.json(
        { ok: false, reason: "Stripe not configured: missing STRIPE_SECRET_KEY.", upgrade: `${appUrl}/upgrade` },
        { status: 200 }
      );
    }

    const Stripe = (await import("stripe")).default;
    const stripe = new Stripe(secret, { apiVersion: "2023-10-16" });

    const body = await req.json().catch(() => ({} as any));
    const plan = (body?.plan ?? "pro") as "pro" | "enterprise";
    const price = plan === "enterprise"
      ? process.env.STRIPE_PRICE_ENTERPRISE
      : process.env.STRIPE_PRICE_PRO;

    if (!price) {
      return NextResponse.json({ ok: false, reason: `Missing price id for ${plan}` }, { status: 200 });
    }

    const session = await stripe.checkout.sessions.create({
      mode: "subscription",
      line_items: [{ price, quantity: 1 }],
      success_url: `${appUrl}/?checkout=success`,
      cancel_url: `${appUrl}/upgrade?cancel=1`
    });

    return NextResponse.json({ ok: true, url: session.url, id: session.id }, { status: 200 });
  } catch (err: any) {
    return NextResponse.json({ ok: false, error: err?.message ?? String(err) }, { status: 200 });
  }
}