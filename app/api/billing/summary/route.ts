
import { NextResponse } from "next/server";
import Stripe from "stripe";

export async function GET(){
  const key = process.env.STRIPE_SECRET_KEY;
  if(!key) return NextResponse.json({ mrr: 0, activeSubscriptions: 0 }, { status: 200 });
  const stripe = new Stripe(key, { apiVersion: "2024-06-20" });
  const subs = await stripe.subscriptions.list({ limit: 100, status: "active" });
  let mrr = 0;
  for(const s of subs.data){
    for(const item of s.items.data){
      const price = item.price;
      if(price?.recurring?.interval === "month" && typeof price.unit_amount === "number"){
        const qty = item.quantity || 1;
        mrr += (price.unit_amount * qty) / 100.0;
      }
    }
  }
  return NextResponse.json({ mrr: Math.round(mrr), activeSubscriptions: subs.data.length });
}
