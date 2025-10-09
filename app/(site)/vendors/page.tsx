export const dynamic = "force-static";

export default function Page() {
  return (
    <div className="p-8 max-w-5xl mx-auto">
      <h1 className="text-3xl font-bold mb-4">For Vendors</h1>
      <p className="text-slate-700">
        Complete once, share everywhere. Publish a verified Trust Badge, manage evidence centrally,
        and accelerate security reviews with buyers.
      </p>
      <ul className="list-disc ml-5 mt-4 space-y-1">
        <li>Unified control library & evidence attachments</li>
        <li>Suggestive fixes & maturity scoring</li>
        <li>Shareable trust profile and API</li>
      </ul>
    </div>
  );
}