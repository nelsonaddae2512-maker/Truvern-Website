export const dynamic = "force-static";

export const metadata = {
  title: "Blog • Truvern",
  description: "News and product updates."
};

export default function Page() {
  return (
    <main className="px-6 py-12 md:py-16">
      <div className="max-w-5xl mx-auto">
        <h1 className="text-3xl md:text-4xl font-semibold mb-4">Truvern Blog</h1>
        <p className="text-neutral-600 leading-relaxed">Stories, launches, and guides to vendor trust.</p>
      </div>
    </main>
  );
}