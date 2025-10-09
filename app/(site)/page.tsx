import Link from "next/link";
export const dynamic = "force-static";

export default function Page() {
  return (
    <section className="px-6 py-16">
      <div className="max-w-6xl mx-auto grid md:grid-cols-2 gap-10 items-center">
        <div>
          <h1 className="text-4xl md:text-5xl font-bold leading-tight">
            Vendor Trust Network for buyers & suppliers
          </h1>
          <p className="mt-4 text-lg text-slate-600">
            Reduce questionnaires, centralize evidence, and share trusted posture everywhere.
          </p>
          <div className="mt-6 flex gap-3">
            <Link href="/vendors" className="px-5 py-2 rounded-lg bg-black text-white">For Vendors</Link>
            <Link href="/buyers" className="px-5 py-2 rounded-lg border">For Buyers</Link>
          </div>
        </div>
        <div className="border rounded-2xl p-6">
          <h3 className="font-semibold mb-2">Why Truvern?</h3>
          <ul className="list-disc ml-5 space-y-1 text-slate-700">
            <li>One assessment, many buyers</li>
            <li>Attach evidence once, reuse often</li>
            <li>Automated trust badge & directory listing</li>
          </ul>
        </div>
      </div>
    </section>
  );
}