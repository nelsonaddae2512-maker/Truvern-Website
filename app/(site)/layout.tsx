export const metadata = {
  title: "Truvern – Vendor Trust Network",
  description: "Verify once, share everywhere. Vendors and buyers connect with trust.",
};
import Link from "next/link";

export default function SiteLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className="min-h-screen bg-white text-slate-900">
        <header className="border-b">
          <nav className="max-w-6xl mx-auto px-6 h-14 flex items-center gap-6">
            <Link href="/" className="font-semibold">Truvern</Link>
            <div className="flex-1" />
            <Link href="/features" className="hover:underline">Features</Link>
            <Link href="/vendors" className="hover:underline">Vendors</Link>
            <Link href="/buyers" className="hover:underline">Buyers</Link>
            <Link href="/trust-network" className="hover:underline">Trust Network</Link>
          </nav>
        </header>
        <main>{children}</main>
        <footer className="border-t mt-16">
          <div className="max-w-6xl mx-auto px-6 py-10 text-sm text-slate-600">
            © {new Date().getFullYear()} Truvern — Verify once, share everywhere.
          </div>
        </footer>
      </body>
    </html>
  );
}