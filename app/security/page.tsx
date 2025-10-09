export const dynamic = "force-static";

export const metadata = {
  title: "Security • Truvern",
  description: "Security, compliance and data handling."
};

export default function Page() {
  return (
    <main className="px-6 py-12 md:py-16">
      <div className="max-w-5xl mx-auto">
        <h1 className="text-3xl md:text-4xl font-semibold mb-4">Security & Compliance</h1>
        <p className="text-neutral-600 leading-relaxed">We follow secure development practices and provide evidence upon request.</p>
      </div>
    </main>
  );
}