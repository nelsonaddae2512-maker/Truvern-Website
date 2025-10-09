export const dynamic = "force-dynamic";

export default function Page(){
  return (
    <main className="p-8 max-w-5xl mx-auto">
      <h1 className="text-3xl font-semibold">Pricing</h1>
      <div className="grid md:grid-cols-3 gap-6 mt-6">
        <div className="border rounded-xl p-6">
          <h2 className="font-semibold">Starter</h2>
          <p className="mt-2">$0/mo</p>
          <ul className="mt-3 list-disc pl-6 text-neutral-700">
            <li>Basic trust profile</li>
            <li>Public badge</li>
          </ul>
        </div>
        <div className="border rounded-xl p-6">
          <h2 className="font-semibold">Pro</h2>
          <p className="mt-2">$199/mo</p>
          <ul className="mt-3 list-disc pl-6 text-neutral-700">
            <li>Evidence library</li>
            <li>Buyer report</li>
            <li>Email support</li>
          </ul>
        </div>
        <div className="border rounded-xl p-6">
          <h2 className="font-semibold">Enterprise</h2>
          <p className="mt-2">Contact us</p>
          <ul className="mt-3 list-disc pl-6 text-neutral-700">
            <li>SSO, audit trails</li>
            <li>Custom workflows</li>
            <li>SLA support</li>
          </ul>
        </div>
      </div>
    </main>
  );
}