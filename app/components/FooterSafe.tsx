"use client";
export default function FooterSafe() {
  return (
    <footer className="mt-16 border-t border-zinc-200/60 px-6 py-10 text-sm text-zinc-500">
      <div className="mx-auto max-w-6xl flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
        <p>© {new Date().getFullYear()} Truvern. All rights reserved.</p>
        <nav className="flex gap-4">
          <a href="/pricing" className="hover:underline">Pricing</a>
          <a href="/contact" className="hover:underline">Contact</a>
          <a href="/trust-network" className="hover:underline">Trust Network</a>
        </nav>
      </div>
    </footer>
  );
}
