"use client";


import { ensureArray } from '@/app/lib/safe';
import Link from "next/link";
import { usePathname } from "next/navigation";
import clsx from "clsx";

export default function Header() {
  const pathname = usePathname();

  const links = [
    { href: "/", label: "Home" },
    { href: "/trust", label: "Trust Network" },
    { href: "/vendors", label: "Vendors" },
    { href: "/pricing", label: "Pricing" },
    { href: "/contact", label: "Contact" },
  ];

  return (
    <header className="border-b bg-white/80 backdrop-blur-md sticky top-0 z-50">
      <div className="max-w-7xl mx-auto flex items-center justify-between px-6 py-4">
        <Link href="/" className="text-xl font-semibold tracking-tight">
          Truvern
        </Link>
        <nav className="hidden md:flex gap-6 text-sm font-medium">
          {links.map((link) => (
            <Link
              key={link.href}
              href={link.href}
              className={clsx(
                "hover:text-blue-600 transition-colors",
                pathname === link.href && "text-blue-600 font-semibold"
              )}
            >
              {link.label}
            </Link>
          ))}
        </nav>
        <div className="flex items-center gap-3">
          <Link
            href="/login"
            className="text-sm text-gray-700 hover:text-blue-600 transition"
          >
            Login
          </Link>
          <Link
            href="/signup"
            className="rounded-md bg-blue-600 text-white text-sm px-4 py-2 hover:bg-blue-700 transition"
          >
            Get Started
          </Link>
        </div>
      </div>
    </header>
  );
}

