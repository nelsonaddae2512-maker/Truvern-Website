import { ensureArray } from '@/app/lib/safe';
// app/dashboard/evidence/page.tsx
export const dynamic = "force-static";

export default function EvidencePage() {
  return (
    <main className="p-6">
      <h1 className="text-xl font-semibold">Evidence Dashboard</h1>
      <p>Placeholder page for /dashboard/evidence.</p>
    </main>
  );
}



export const metadata = {
  title: "Evidence",
  description: "Upload and review evidence inside the Truvern dashboard.",
  alternates: { canonical: "/dashboard/evidence" },
  openGraph: { images: ["/opengraph-image.png"] },
  icons: { icon: "/favicon.ico" }
};
