export const metadata = {
  title: "Features – Truvern",
  description: "Key capabilities of the Truvern Vendor Trust Network.",
};

export default async function FeaturesPage() {
  const features = [
    { title: "Interactive Assessments", text: "Send, score, and compare vendor questionnaires." },
    { title: "Trust Network", text: "Reuse evidence shared across the network to move faster." },
    { title: "Board Reports", text: "One-click executive summaries and KPIs." },
    { title: "Remediation Workflows", text: "Track issues with SLAs and ownership." },
    { title: "Tiering & Scoring", text: "Dynamic vendor tiers with risk auto-bumps." },
  ];

  return (
    <main className="container-page py-8">
      <h1 className="text-2xl font-semibold tracking-tight">Features</h1>
      <p className="mt-2 text-sm text-zinc-500">
        Server-rendered placeholder to satisfy prerender; replace with the full marketing content later.
      </p>

      <div className="mt-6 grid gap-4 sm:grid-cols-2">
        {features.map((f, i) => (
          <div key={i} className="rounded-md border border-zinc-200 dark:border-zinc-800 p-4">
            <h2 className="text-sm font-medium">{f.title}</h2>
            <p className="mt-2 text-sm text-zinc-600 dark:text-zinc-400">{f.text}</p>
          </div>
        ))}
      </div>

      <div className="mt-8">
        <a className="underline text-sm" href="/pricing">See pricing</a>
      </div>
    </main>
  );
}