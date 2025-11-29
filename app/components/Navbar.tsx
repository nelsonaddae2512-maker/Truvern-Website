"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";

export default function Navbar() {
  const pathname = usePathname();
  const LinkItem = ({ href, label }: { href: string; label: string }) => (
    <Link
      href={href}
      className={`px-3 py-2 rounded-lg hover:opacity-90 ${pathname===href ? "bg-white/10" : ""}`}
    >
      {label}
    </Link>
  );

  return (
    <header className="border-b border-white/10 sticky top-0 z-50 bg-black/30 backdrop-blur">
      <div className="container flex items-center justify-between">
        <Link href="/" className="font-semibold tracking-tight">Truvern</Link>
        <nav className="flex items-center gap-1">
          <LinkItem href="/" label="Home" />
          <LinkItem href="/trust-network" label="Trust Network" />
          <LinkItem href="/vendors" label="Vendors" />
          <LinkItem href="/reports/board" label="Board Report" />
        </nav>
        <div className="flex items-center gap-2">
          <Link href="/login" className="btn">Log in</Link>
          <Link href="/signup" className="btn btn-primary">Sign up</Link>
        </div>
      </div>
    </header>
  );
}
