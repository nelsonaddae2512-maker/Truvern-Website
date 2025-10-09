export const dynamic = "force-static";

export default function Page() {
  return (
    <div className="p-8 max-w-5xl mx-auto">
      <h1 className="text-3xl font-bold mb-4">For Buyers</h1>
      <p className="text-slate-700">
        Search vendors by framework, review evidence status, and subscribe to continuous posture updates.
      </p>
      <ul className="list-disc ml-5 mt-4 space-y-1">
        <li>Directory with filters (SOC 2, ISO 27001, HIPAA, etc.)</li>
        <li>Evidence status and reviewer workflow</li>
        <li>Automated trust score & badge verification</li>
      </ul>
    </div>
  );
}