export const dynamic = "force-static";

export const metadata = {
  title: "Docs â€¢ Truvern",
  description: "Developer & API documentation."
};

export default function Page() {
  return (
    <main className="px-6 py-12 md:py-16">
      <div className="max-w-5xl mx-auto">
        <h1 className="text-3xl md:text-4xl font-semibold mb-4">Developer Docs</h1>
        <p className="text-neutral-600 leading-relaxed">SDKs, API references, and integration guides (Stripe, SSO, Webhooks).</p>
      </div>
    </main>
  );
}

