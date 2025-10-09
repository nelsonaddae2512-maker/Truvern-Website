export const dynamic = "force-static";

export default function Page() {
  return (
    <div className="p-8 max-w-5xl mx-auto">
      <h1 className="text-3xl font-bold mb-4">Features</h1>
      <div className="grid md:grid-cols-2 gap-6">
        <div className="border rounded-xl p-5">
          <h3 className="font-semibold">Assessment Engine</h3>
          <p className="text-slate-700 mt-2">Control-level checks, maturity scoring, and fixes.</p>
        </div>
        <div className="border rounded-xl p-5">
          <h3 className="font-semibold">Evidence Hub</h3>
          <p className="text-slate-700 mt-2">Attach once, reuse across frameworks and buyers.</p>
        </div>
        <div className="border rounded-xl p-5">
          <h3 className="font-semibold">Trust Badge</h3>
          <p className="text-slate-700 mt-2">Embed your up-to-date trust signal anywhere.</p>
        </div>
        <div className="border rounded-xl p-5">
          <h3 className="font-semibold">Directory</h3>
          <p className="text-slate-700 mt-2">Global vendor discovery with posture filters.</p>
        </div>
      </div>
    </div>
  );
}