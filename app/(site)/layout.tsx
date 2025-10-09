import React from "react";

export default function SiteLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <header className="px-6 py-4 border-b">
          <nav className="max-w-6xl mx-auto flex items-center gap-6">
            <a href="/" className="font-semibold">Truvern</a>
            <a href="/buyers">Buyers</a>
            <a href="/vendors">Vendors</a>
            <a href="/features">Features</a>
            <a href="/trust-network">Trust Network</a>
          </nav>
        </header>
        <main>{children}</main>
        <footer className="px-6 py-8 border-t mt-16">
          <div className="max-w-6xl mx-auto text-sm text-gray-500">
            © Truvern. Verify once, share everywhere.
          </div>
        </footer>
      </body>
    </html>
  );
}