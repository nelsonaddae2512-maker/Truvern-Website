export const runtime = "nodejs";

import { NextResponse } from 'next/server';
import Stripe from 'stripe';
import { getServerSession } from 'next-auth';
import { authOptions } from '@/lib/auth';
import { prisma } from '@/lib/prisma';

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, { apiVersion: '2024-06-20' });

export async function POST(){
  const session = await getServerSession(authOptions);
  const me = session?.user as any;
  if(!me?.organizationId) return NextResponse.json({ error:'Unauthorized' }, { status: 401 });
  const org = await prisma.organization.findUnique({ where: { id: me.organizationId } });
  if(!org?.stripeCustomerId) return NextResponse.json({ error:'No Stripe customer' }, { status: 404 });
  if(process.env.STRIPE_BILLING_PORTAL_URL){ return NextResponse.json({ url: process.env.STRIPE_BILLING_PORTAL_URL }); }
  const portal = await stripe.billingPortal.sessions.create({ customer: org.stripeCustomerId, return_url: `${process.env.NEXTAUTH_URL || 'http://localhost:3000'}/dashboard` });
  return NextResponse.json({ url: portal.url });
}
