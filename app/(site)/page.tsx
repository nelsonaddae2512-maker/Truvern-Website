import Link from "next/link";

export const dynamic = "force-dynamic";

export default function HomePage(){
  return (
    <main>
      <section className="px-6 py-16 text-center">
        <h1 className="text-4xl md:text-5xl font-semibold">Truvern Vendor Trust Network</h1>
        <p className="mt-4 text-neutral-600 max-w-2xl mx-auto">
          Verify once, share everywhere — a faster way for vendors to prove trust and for buyers to evaluate risk.
        </p>
        <div className="mt-8 flex gap-3 justify-center">
          <Link href="/vendors" className="px-5 py-3 rounded-lg bg-black text-white">For Vendors</Link>
          <Link href="/buyers" className="px-5 py-3 rounded-lg border">For Buyers</Link>
        </div>
      </section>
    </main>
  );
}