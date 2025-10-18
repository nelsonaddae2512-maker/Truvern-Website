export const dynamic = "force-static";

export const metadata = {
  title: "About â€¢ Truvern",
  description: "Why we built the Vendor Trust Network."
};

export default function Page() {
  return (
    <main className="px-6 py-12 md:py-16">
      <div className="max-w-5xl mx-auto">
        <h1 className="text-3xl md:text-4xl font-semibold mb-4">About Truvern</h1>
        <p className="text-neutral-600 leading-relaxed">We reduce repeated questionnaires and centralize proof onceâ€”shared everywhere.</p>
      </div>
    </main>
  );
}

