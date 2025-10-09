export const dynamic = "force-dynamic";

export default function Page(){
  return (
    <main className="p-8 max-w-5xl mx-auto">
      <h1 className="text-3xl font-semibold">Features</h1>
      <div className="grid md:grid-cols-2 gap-6 mt-6">
        <div className="border rounded-xl p-6">
          <h2 className="font-semibold">Unified Questionnaire Engine</h2>
          <p className="text-neutral-700 mt-2">Answer once, map to multiple frameworks.</p>
        </div>
        <div className="border rounded-xl p-6">
          <h2 className="font-semibold">Evidence Library</h2>
          <p className="text-neutral-700 mt-2">Attach, version, and attest documents.</p>
        </div>
        <div className="border rounded-xl p-6">
          <h2 className="font-semibold">Trust Badge</h2>
          <p className="text-neutral-700 mt-2">Show real-time status on your website.</p>
        </div>
        <div className="border rounded-xl p-6">
          <h2 className="font-semibold">Buyer Reports</h2>
          <p className="text-neutral-700 mt-2">One-click board & security reports.</p>
        </div>
      </div>
    </main>
  );
}