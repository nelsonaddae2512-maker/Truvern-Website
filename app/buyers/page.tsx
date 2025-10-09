export const dynamic = "force-dynamic";

export default function Page(){
  return (
    <main className="p-8 max-w-5xl mx-auto">
      <h1 className="text-3xl font-semibold">For Buyers</h1>
      <p className="mt-3 text-neutral-700">
        See standardized control answers, linked evidence, and real-time trust signals across vendors.
      </p>
      <ul className="mt-6 list-disc pl-6 space-y-2 text-neutral-800">
        <li>Comparable control coverage and maturity</li>
        <li>Evidence attestation & review workflow</li>
        <li>Instant summaries and audit trails</li>
      </ul>
    </main>
  );
}