export const metadata = {
  title: "Buyers – Truvern",
  description: "Buyer-facing resources and onboarding for the Truvern network.",
};

export default async function BuyersPage() {
  return (
    <main className="container-page py-8">
      <h1 className="text-2xl font-semibold tracking-tight">Buyers</h1>
      <p className="mt-2 text-sm text-zinc-500">
        Server-rendered placeholder to satisfy prerender. Replace with real content later.
      </p>

      <section className="mt-6 space-y-4">
        <div className="rounded-md border border-zinc-200 dark:border-zinc-800 p-4">
          <h2 className="text-sm font-medium">Getting started</h2>
          <p className="mt-2 text-sm text-zinc-600 dark:text-zinc-400">
            Invite your team, connect vendors, and run assessments.
          </p>
        </div>
        <div className="rounded-md border border-zinc-200 dark:border-zinc-800 p-4">
          <h2 className="text-sm font-medium">Helpful links</h2>
          <ul className="mt-2 list-disc pl-5 text-sm text-zinc-600 dark:text-zinc-400">
            <li><a className="underline" href="/trust-network">Trust Network</a></li>
            <li><a className="underline" href="/vendors">Vendors</a></li>
            <li><a className="underline" href="/pricing">Pricing</a></li>
          </ul>
        </div>
      </section>
    </main>
  );
}