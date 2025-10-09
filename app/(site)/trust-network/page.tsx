export const dynamic = "force-static";

export default function Page() {
  return (
    <div className="p-8 max-w-5xl mx-auto">
      <h1 className="text-3xl font-bold mb-4">Trust Network</h1>
      <p className="text-slate-700">
        Join a shared network where verified posture travels with you. Reduce friction, increase trust.
      </p>
      <div className="mt-6 grid md:grid-cols-3 gap-6">
        <div className="border rounded-xl p-5">
          <h4 className="font-semibold">Verify Once</h4>
          <p className="text-slate-700 mt-1">Centralize controls & evidence.</p>
        </div>
        <div className="border rounded-xl p-5">
          <h4 className="font-semibold">Share Everywhere</h4>
          <p className="text-slate-700 mt-1">Link your badge to buyers and marketplaces.</p>
        </div>
        <div className="border rounded-xl p-5">
          <h4 className="font-semibold">Stay Current</h4>
          <p className="text-slate-700 mt-1">Automatic updates keep reviewers in sync.</p>
        </div>
      </div>
    </div>
  );
}