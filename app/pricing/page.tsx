export const dynamic = "force-static";

export const metadata = {
  title: "Pricing • Truvern",
  description: "Simple, global pricing for vendors and buyers."
};

export default function Page() {
  return (
    <main className="px-6 py-12 md:py-16">
      <div className="max-w-5xl mx-auto">
        <h1 className="text-3xl md:text-4xl font-semibold mb-4">Pricing</h1>
        <p className="text-neutral-600 leading-relaxed">Choose a plan that matches your volume and assurance needs. Upgrade or downgrade any time.</p>
      </div>
    </main>
  );
}