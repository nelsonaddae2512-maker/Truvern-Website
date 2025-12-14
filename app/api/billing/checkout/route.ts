import { NextResponse } from "next/server";
import { getStripe } from "@/lib/stripe";
import { PLAN_PRICE_IDS } from "@/lib/billing";
import { getOrgContext } from "@/lib/orgContext";

export async function GET(req: Request) {
  try {
    const { searchParams } = new URL(req.url);
    const plan = searchParams.get("plan") || "pro";

    if (!PLAN_PRICE_IDS[plan]) {
      return NextResponse.json({ error: "Unknown plan" }, { status: 400 });
    }

    const { organization } = await getOrgContext();

    // 🔴 NEW: handle "Stripe not configured" without crashing build
    const stripe = getStripe();
    if (!stripe) {
      // For now, just tell the caller Stripe isn't set up.
      // This makes the route *safe* even when STRIPE_SECRET_KEY is missing.
      return NextResponse.json(
        {
          error:
            "Stripe is not configured for this environment. Billing is disabled.",
        },
        { status: 501 }, // Not Implemented
      );
    }

    const session = await stripe.checkout.sessions.create({
      mode: "subscription",
      line_items: [{ price: PLAN_PRICE_IDS[plan], quantity: 1 }],
      success_url: `${process.env.APP_URL}/billing/success`,
      cancel_url: `${process.env.APP_URL}/pricing`,
      client_reference_id: organization.id.toString(),
      customer: organization.stripeCustomerId || undefined,
    });

    return NextResponse.redirect(session.url!, 303);
  } catch (err) {
    console.error(err);
    return NextResponse.json({ error: "Internal error" }, { status: 500 });
  }
}
