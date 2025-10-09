export const dynamic = "force-static";

export const metadata = {
  title: "Directory • Truvern",
  description: "Browse vendors with verified trust badges."
};

export default function Page() {
  return (
    <main className="px-6 py-12 md:py-16">
      <div className="max-w-5xl mx-auto">
        <h1 className="text-3xl md:text-4xl font-semibold mb-4">Vendor Directory</h1>
        <p className="text-neutral-600 leading-relaxed">Search vendors, filter by frameworks, and view trust badges. (Data populates after you connect your database.)</p>
      </div>
    </main>
  );
}