"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useMemo, useRef, useState } from "react";
import { SignedIn, SignedOut, SignInButton, UserButton } from "@clerk/nextjs";

type NavItem = { href: string; label: string };

function cx(...classes: Array<string | false | null | undefined>) {
  return classes.filter(Boolean).join(" ");
}

function CaretDownIcon({ className = "" }: { className?: string }) {
  return (
    <svg
      className={className}
      width="16"
      height="16"
      viewBox="0 0 20 20"
      fill="none"
      aria-hidden="true"
    >
      <path
        d="M5 7.5L10 12.5L15 7.5"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}

function MenuIcon({ className = "" }: { className?: string }) {
  return (
    <svg
      className={className}
      width="20"
      height="20"
      viewBox="0 0 24 24"
      fill="none"
      aria-hidden="true"
    >
      <path
        d="M4 6h16M4 12h16M4 18h16"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
      />
    </svg>
  );
}

function CloseIcon({ className = "" }: { className?: string }) {
  return (
    <svg
      className={className}
      width="20"
      height="20"
      viewBox="0 0 24 24"
      fill="none"
      aria-hidden="true"
    >
      <path
        d="M6 6l12 12M18 6L6 18"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
      />
    </svg>
  );
}

export default function SiteHeader() {
  const pathname = usePathname();

  // ✅ Enterprise polish: “Vendors” becomes “Vendor Portfolio”
  const topNav: NavItem[] = useMemo(
    () => [
      { href: "/", label: "Home" },
      { href: "/trust-network", label: "Trust Network" },
      { href: "/vendors", label: "Vendor Portfolio" }, // ✅ renamed
      { href: "/issues", label: "Issues" },
      { href: "/activity", label: "Activity" },
      { href: "/contact", label: "Contact" },
      { href: "/pricing", label: "Pricing" },
    ],
    []
  );

  // ✅ Enterprise: single canonical Board Report (no legacy links)
  const boardItems: NavItem[] = useMemo(
    () => [{ href: "/board-report", label: "Board Report" }],
    []
  );

  const assessmentItems: NavItem[] = useMemo(
    () => [
      { href: "/assessment", label: "Assessment Runs" },
      { href: "/assessment/templates", label: "Template Manager" },
    ],
    []
  );

  const rootRef = useRef<HTMLDivElement | null>(null);

  const [mobileOpen, setMobileOpen] = useState(false);
  const [boardOpen, setBoardOpen] = useState(false);
  const [assessOpen, setAssessOpen] = useState(false);

  // Vendor-facing portal CTA
  const vendorPortalHref = "/vendor-portal";

  // Close menus on route change (prevents stuck states)
  useEffect(() => {
    setMobileOpen(false);
    setBoardOpen(false);
    setAssessOpen(false);
  }, [pathname]);

  // Close on outside click/tap
  useEffect(() => {
    function onDown(e: MouseEvent | TouchEvent) {
      const el = rootRef.current;
      if (!el) return;
      const target = e.target as Node | null;
      if (target && !el.contains(target)) {
        setBoardOpen(false);
        setAssessOpen(false);
        setMobileOpen(false);
      }
    }
    document.addEventListener("mousedown", onDown);
    document.addEventListener("touchstart", onDown, { passive: true });
    return () => {
      document.removeEventListener("mousedown", onDown);
      document.removeEventListener("touchstart", onDown);
    };
  }, []);

  // Close on Escape
  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      if (e.key === "Escape") {
        setBoardOpen(false);
        setAssessOpen(false);
        setMobileOpen(false);
      }
    }
    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, []);

  function linkTone(href: string) {
    const active =
      pathname === href || (href !== "/" && pathname?.startsWith(href));
    return cx(
      "text-sm font-medium transition-colors",
      active ? "text-emerald-200" : "text-slate-200/80 hover:text-slate-100"
    );
  }

  function dropdownButtonTone(open: boolean) {
    return cx(
      "inline-flex items-center gap-1 text-sm font-medium transition-colors rounded-md px-2 py-1",
      open
        ? "text-emerald-200 bg-white/5"
        : "text-slate-200/80 hover:text-slate-100 hover:bg-white/5"
    );
  }

  return (
    <div
      ref={rootRef}
      className="sticky top-0 z-50 border-b border-white/5 bg-slate-950/75 backdrop-blur supports-[backdrop-filter]:bg-slate-950/55"
    >
      <div className="mx-auto flex max-w-6xl items-center justify-between gap-3 px-4 py-3">
        {/* Left: Brand + Seal */}
        <div className="flex items-center gap-3">
          <Link
            href="/"
            className="text-lg font-semibold tracking-tight text-emerald-200 hover:text-emerald-100"
          >
            Truvern
          </Link>

          <div className="hidden items-center gap-2 rounded-full border border-emerald-500/30 bg-emerald-500/10 px-3 py-1 text-xs text-emerald-200 md:flex">
            <span className="inline-block h-2 w-2 rounded-full bg-emerald-400" />
            <span className="font-medium">Integrity Seal</span>
            <span className="text-emerald-200/70">Verified</span>
          </div>
        </div>

        {/* Center: Desktop Nav */}
        <nav className="hidden items-center gap-5 md:flex">
          {topNav.map((it) => (
            <Link key={it.href} href={it.href} className={linkTone(it.href)}>
              {it.label}
            </Link>
          ))}

          {/* Board dropdown (CLICK ONLY) */}
          <div className="relative">
            <button
              type="button"
              className={dropdownButtonTone(boardOpen)}
              aria-haspopup="menu"
              aria-expanded={boardOpen}
              onClick={() => {
                setBoardOpen((v) => !v);
                setAssessOpen(false);
              }}
            >
              Board Report
              <CaretDownIcon
                className={cx("transition-transform", boardOpen && "rotate-180")}
              />
            </button>

            {boardOpen && (
              <div
                className="absolute left-0 mt-2 w-56 overflow-hidden rounded-xl border border-white/10 bg-slate-950 shadow-xl"
                role="menu"
              >
                <div className="p-1">
                  {boardItems.map((it) => (
                    <Link
                      key={it.href}
                      href={it.href}
                      className="block rounded-lg px-3 py-2 text-sm text-slate-200/90 hover:bg-white/5 hover:text-slate-50"
                      role="menuitem"
                      onClick={() => setBoardOpen(false)}
                    >
                      {it.label}
                    </Link>
                  ))}
                </div>
              </div>
            )}
          </div>

          {/* Assessment dropdown (CLICK ONLY) */}
          <div className="relative">
            <button
              type="button"
              className={dropdownButtonTone(assessOpen)}
              aria-haspopup="menu"
              aria-expanded={assessOpen}
              onClick={() => {
                setAssessOpen((v) => !v);
                setBoardOpen(false);
              }}
            >
              Assessment
              <CaretDownIcon
                className={cx("transition-transform", assessOpen && "rotate-180")}
              />
            </button>

            {assessOpen && (
              <div
                className="absolute left-0 mt-2 w-64 overflow-hidden rounded-xl border border-white/10 bg-slate-950 shadow-xl"
                role="menu"
              >
                <div className="p-1">
                  {assessmentItems.map((it) => (
                    <Link
                      key={it.href}
                      href={it.href}
                      className="block rounded-lg px-3 py-2 text-sm text-slate-200/90 hover:bg-white/5 hover:text-slate-50"
                      role="menuitem"
                      onClick={() => setAssessOpen(false)}
                    >
                      {it.label}
                    </Link>
                  ))}
                </div>
              </div>
            )}
          </div>
        </nav>

        {/* Right: CTA + Auth + Mobile toggle */}
        <div className="flex items-center gap-2">
          {/* ✅ Enterprise polish: clearer external-facing CTA label */}
          <Link
            href={vendorPortalHref}
            className="hidden rounded-full border border-emerald-500/30 bg-emerald-500/10 px-4 py-2 text-sm font-medium text-emerald-100 hover:bg-emerald-500/15 md:inline-flex"
            title="Vendor Portal (external)"
          >
            Vendor Portal
          </Link>

          <SignedOut>
            <SignInButton mode="modal">
              <button className="rounded-full border border-white/10 bg-white/5 px-4 py-2 text-sm font-medium text-slate-100 hover:bg-white/10">
                Sign in
              </button>
            </SignInButton>
          </SignedOut>

          <SignedIn>
            <UserButton afterSignOutUrl="/" />
          </SignedIn>

          <button
            type="button"
            className="inline-flex items-center justify-center rounded-lg border border-white/10 bg-white/5 p-2 text-slate-100 hover:bg-white/10 md:hidden"
            aria-label="Toggle menu"
            aria-expanded={mobileOpen}
            onClick={() => setMobileOpen((v) => !v)}
          >
            {mobileOpen ? <CloseIcon /> : <MenuIcon />}
          </button>
        </div>
      </div>

      {/* Mobile panel */}
      {mobileOpen && (
        <div className="border-t border-white/5 bg-slate-950/95 md:hidden">
          <div className="mx-auto max-w-6xl px-4 py-3">
            <div className="grid gap-1">
              {topNav.map((it) => (
                <Link
                  key={it.href}
                  href={it.href}
                  className="rounded-lg px-3 py-2 text-sm text-slate-200/90 hover:bg-white/5 hover:text-slate-50"
                  onClick={() => setMobileOpen(false)}
                >
                  {it.label}
                </Link>
              ))}

              <div className="my-2 border-t border-white/10" />

              {[...boardItems, ...assessmentItems].map((it) => (
                <Link
                  key={it.href}
                  href={it.href}
                  className="rounded-lg px-3 py-2 text-sm text-slate-200/90 hover:bg-white/5 hover:text-slate-50"
                  onClick={() => setMobileOpen(false)}
                >
                  {it.label}
                </Link>
              ))}

              <div className="my-2 border-t border-white/10" />

              <Link
                href={vendorPortalHref}
                className="rounded-lg border border-emerald-500/25 bg-emerald-500/10 px-3 py-2 text-sm font-medium text-emerald-100 hover:bg-emerald-500/15"
                onClick={() => setMobileOpen(false)}
              >
                Vendor Portal
              </Link>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
