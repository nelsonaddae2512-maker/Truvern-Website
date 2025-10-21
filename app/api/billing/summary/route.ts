import prisma from "@/lib/db";

export const runtime = "nodejs"
export const dynamic = "force-dynamic";
import { NextResponse } from "next/server"
export async function GET(){
  try {
    const key = process.env.STRIPE_SECRET_KEY || process.env.STRIPE_SECRET || "";
    if (!key) {
      return NextResponse.json(
        { ok: true, provider: "stripe", mrr: 0, activeSubscriptions: 0, note: "missing STRIPE_SECRET_KEY" },
        { status: 200 }
      );
    }

    // Lazy import to avoid build-time side effects
    const { default: Stripe } = await import("stripe");
    const stripe = new Stripe(key, { apiVersion: "2024-06-20" } as any);

    // Pull active subs (adjust filters/expand as needed)
    const subs = await stripe.subscriptions.list({ limit: 100, status: "active" });

    let mrr = 0;
    let active = 0;

    for (const s of subs.data) {
      if (s.status === "active") {
        active++;
        const item = s.items?.data?.[0];
        const amount = (item?.price?.unit_amount ?? 0); // cents
        const interval = item?.price?.recurring?.interval; // "month" | "year" | etc.
        const qty = item?.quantity ?? 1;

        if (interval === "month") {
          mrr += (amount / 100) * qty;
        } else if (interval === "year") {
          mrr += ((amount / 100) * qty) / 12;
        }
      }
    }

    // Round to 2 decimals for display
    mrr = Math.round(mrr * 100) / 100;

    return NextResponse.json(
      { ok: true, provider: "stripe", mrr, activeSubscriptions: active },
      { status: 200 }
    );
  } catch (e) {
    // Never break build; return benign payload
    return NextResponse.json(
      { ok: false, provider: "stripe", mrr: 0, activeSubscriptions: 0, error: "internal" },
      { status: 200 }
    );
  }
}

