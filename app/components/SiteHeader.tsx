"use client";

import Link from "next/link";
import Image from "next/image";
import { usePathname } from "next/navigation";
import { IntegrityStatusBadge } from "@/components/IntegrityStatusBadge";

const navItems = [
  { href: "/", label: "Home" },
  { href: "/trust-network", label: "Trust Network" },
  { href: "/vendors", label: "Vendors" },
  { href: "/reports/board", label: "Board Report" },
];

export function SiteHeader() {
  const pathname = usePathname();

  return (
    <header className="border-b border-slate-800/70 bg-slate-950/95">
      <div className="mx-auto flex max-w-6xl items-center justify-between gap-4 px-4 py-3">
        {/* Left: logo + nav */}
        <div className="flex items-center gap-8">
          {/* Logo with subtle glow when OK */}
          <Link href="/" className="group flex items-center gap-2">
            <div className="rounded-full p-[2px] transition duration-300 group-hover:drop-shadow-[0_0_16px_rgba(45,212,191,0.7)]">
              <Image
                src="/brand/truvern-shield.svg" // your chosen app logo in /public/brand
                alt="Truvern"
                width={32}
                height={32}
                className="h-8 w-auto transition-transform duration-300 group-hover:scale-110"
                priority
              />
            </div>
            <span className="sr-only">Truvern</span>
          </Link>

          {/* Nav links */}
          <nav className="flex items-center gap-5 text-sm text-slate-300">
            {navItems.map((item) => {
              const isActive =
                item.href === "/"
                  ? pathname === "/"
                  : pathname.startsWith(item.href);

              return (
                <Link
                  key={item.href}
                  href={item.href}
                  className={`border-b-2 pb-1 transition ${
                    isActive
                      ? "border-sky-400 text-slate-50"
                      : "border-transparent text-slate-300 hover:text-slate-100"
                  }`}
                >
                  {item.label}
                </Link>
              );
            })}
          </nav>
        </div>

        {/* Right: live integrity chip */}
        <div className="hidden items-center md:flex">
          <IntegrityStatusBadge compact />
        </div>
      </div>
    </header>
  );
}

export default SiteHeader;
