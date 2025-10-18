export const dynamic = "force-static";

export const metadata = {
  title: "Buyer Workspace â€¢ Truvern",
  description: "Review vendors and request evidence."
};

export default function Page() {
  return (
    <main className="px-6 py-12 md:py-16">
      <div className="max-w-5xl mx-auto">
        <h1 className="text-3xl md:text-4xl font-semibold mb-4">Buyer Workspace</h1>
        <p className="text-neutral-600 leading-relaxed">Search vendors, request info, and record review outcomes.</p>
      </div>
    </main>
  );
}

