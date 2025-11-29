import { NextResponse } from "next/server";
export const runtime = "nodejs";

export async function POST(req: Request) {
  const secret = process.env.STRIPE_SECRET_KEY;
  const whsec = process.env.STRIPE_WEBHOOK_SECRET;
  if (!secret) return NextResponse.json({ ok: true, note: "Stripe not configured" }, { status: 200 });

  const Stripe = (await import("stripe")).default;
  const stripe = new Stripe(secret, { apiVersion: "2023-10-16" });

  const body = await req.text();
  const sig  = (req.headers.get("stripe-signature") ?? "");

  try {
    const evt = whsec ? stripe.webhooks.constructEvent(body, sig, whsec) : JSON.parse(body);
    switch (evt.type) {
      case "checkout.session.completed":
      case "customer.subscription.created":
      case "customer.subscription.updated":
        // TODO: mark org plan=pro/enterprise in DB
        break;
      default:
        break;
    }
    return NextResponse.json({ received: true }, { status: 200 });
  } catch (err:any) {
    return NextResponse.json({ error: err?.message ?? "invalid payload" }, { status: 400 });
  }
}