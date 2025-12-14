import { NextResponse } from "next/server";
import { stripe } from "@/lib/stripe";
import prisma from "@/lib/prisma";

async function buffer(req: Request) {
  const chunks: Uint8Array[] = [];
  const reader = req.body?.getReader();
  if (!reader) return new Uint8Array();

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    if (value) chunks.push(value);
  }

  return Buffer.concat(chunks);
}

export async function POST(req: Request) {
  const sig = req.headers.get("stripe-signature") || "";
  const buf = await buffer(req);

  let event;
  try {
    event = stripe.webhooks.constructEvent(
      buf,
      sig,
      process.env.STRIPE_WEBHOOK_SECRET!,
    );
  } catch (err: any) {
    console.error("Stripe webhook error:", err.message);
    return NextResponse.json({ error: "Invalid signature" }, { status: 400 });
  }

  try {
    if (event.type === "checkout.session.completed") {
      const session = event.data.object as any;
      const orgId = Number(session.client_reference_id);
      if (!Number.isNaN(orgId)) {
        await prisma.organization.update({
          where: { id: orgId },
          data: {
            subscriptionTier: "pro",
            stripeCustomerId: session.customer as string,
          },
        });
      }
    }

    return NextResponse.json({ received: true }, { status: 200 });
  } catch (err) {
    console.error(err);
    return NextResponse.json({ error: "Webhook handling error" }, { status: 500 });
  }
}
