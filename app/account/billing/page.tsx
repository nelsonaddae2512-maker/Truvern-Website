import { ensureArray } from '@/app/lib/safe';
export const dynamic = "force-dynamic";
export default function Page() {
  return (
    <main style={{padding:24}}>
      <h1>Account billing</h1>
      <p>Open the customer billing portal (requires a Stripe Customer ID).</p>
      <form method="get" action="/api/stripe/portal">
        <input name="cid" placeholder="cus_123..." />
        <button type="submit">Open Billing Portal</button>
      </form>
    </main>
  );
}


