export const runtime = "nodejs";

import { NextResponse } from 'next/server';
import Stripe from 'stripe';
import { getServerSession } from 'next-auth';
import { authOptions } from '@/lib/auth';
import { prisma } from '@/lib/prisma';

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, { apiVersion: '2024-06-20' });
const PRICE_MAP: Record<string,string|undefined> = {
  starter: process.env.PRICE_STARTER_MONTHLY,
  pro: process.env.PRICE_PRO_MONTHLY,
  enterprise: process.env.PRICE_ENTERPRISE_MONTHLY,
};
export async function POST(req: Request){
  const session = await getServerSession(authOptions);
  const me = session?.user as any;
  if(!me?.organizationId) return NextResponse.json({ error:'Unauthorized' }, { status: 401 });
  const { tier } = await req.json().catch(()=>({})) as { tier?: 'starter'|'pro'|'enterprise' };
  if(!tier || !PRICE_MAP[tier]) return NextResponse.json({ error:'Invalid tier' }, { status: 400 });
  const org = await prisma.organization.findUnique({ where: { id: me.organizationId } });
  if(!org) return NextResponse.json({ error:'Org not found' }, { status: 404 });
  let customerId = org.stripeCustomerId || undefined;
  if(!customerId){
    const customer = await stripe.customers.create({ email: (session as any).user?.email || undefined, name: org.name, metadata: { orgId: org.id }});
    customerId = customer.id;
    await prisma.organization.update({ where: { id: org.id }, data: { stripeCustomerId: customerId }});
  }
  const base = process.env.NEXTAUTH_URL || 'http://localhost:3000';
  const checkout = await stripe.checkout.sessions.create({
    mode: 'subscription',
    customer: customerId,
    line_items: [{ price: PRICE_MAP[tier]!, quantity: 1 }],
    success_url: `${base}/dashboard?sub=success`,
    cancel_url: `${base}/subscribe?canceled=1`,
    allow_promotion_codes: true,
    subscription_data: { metadata: { orgId: org.id, tier } },
    metadata: { orgId: org.id, tier },
  });
  return NextResponse.json({ url: checkout.url });
}
