import { ensureArray } from '@/app/lib/safe';
export const dynamic = "force-dynamic";
export default function Page() {
  return (
    <main style={{padding:24}}>
      <h1>Upgrade</h1>
      <p>Choose a plan to unlock CSV exports and more.</p>
      <form method="post" action="/api/stripe/checkout">
        <input type="hidden" name="plan" value="pro" />
        <button formAction="/api/stripe/checkout" onClick={(e)=>{}} >Start Pro Checkout</button>
      </form>
      <p style={{marginTop:16,fontSize:12,opacity:.7}}>
        Server must have STRIPE_SECRET_KEY and STRIPE_PRICE_PRO set.
      </p>
    </main>
  );
}
