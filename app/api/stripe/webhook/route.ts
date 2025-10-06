
import { headers } from 'next/headers';
import { NextResponse } from 'next/server';
import Stripe from 'stripe';
import { prisma } from '@/lib/prisma';
const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, { apiVersion: '2024-06-20' });
function tierToSeats(tier:string){return tier==='starter'?3:9999;}
export async function POST(req:Request){
  const buf = await req.arrayBuffer();
  const sig = (await headers()).get('stripe-signature')!;
  let event: Stripe.Event;
  try{event = stripe.webhooks.constructEvent(Buffer.from(buf), sig, process.env.STRIPE_WEBHOOK_SECRET!);}catch(err:any){return NextResponse.json({error:`Webhook Error: ${err.message}`},{status:400});}
  try{
    switch(event.type){
      case 'checkout.session.completed':{
        const cs = event.data.object as Stripe.Checkout.Session;
        const orgId = cs.metadata?.orgId as string|undefined; const tier = cs.metadata?.tier as string|undefined;
        if(orgId && tier){await prisma.organization.update({where:{id:orgId},data:{plan:tier,seats:tierToSeats(tier),stripeSubscriptionId:cs.subscription?.toString()||undefined,subscriptionStatus:'active'}});}
        break;
      }
      case 'customer.subscription.updated':
      case 'customer.subscription.created':{
        const sub = event.data.object as Stripe.Subscription;
        const orgId = (sub.metadata as any)?.orgId; const tier = (sub.metadata as any)?.tier;
        if(orgId){await prisma.organization.update({where:{id:orgId},data:{plan:tier,seats:tierToSeats(tier),stripeSubscriptionId:sub.id,subscriptionStatus:sub.status,currentPeriodEnd:new Date(sub.current_period_end*1000)}});}
        break;
      }
      case 'customer.subscription.deleted':{
        const sub = event.data.object as Stripe.Subscription;
        const org = await prisma.organization.findFirst({where:{stripeSubscriptionId:sub.id}});
        if(org){await prisma.organization.update({where:{id:org.id},data:{plan:'free',seats:3,subscriptionStatus:'canceled',currentPeriodEnd:new Date()}});}
        break;
      }
      default:break;
    }
  }catch(e){console.error('Webhook handling error',e);return NextResponse.json({error:'Failure'},{status:500});}
  return NextResponse.json({received:true});
}
