// app/vendor/layout.tsx
import Link from "next/link";

export const dynamic = "force-dynamic";
export const revalidate = 0;

function clsx(...parts: Array<string | false | null | undefined>) {
  return parts.filter(Boolean).join(" ");
}

export default function VendorPortalLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="min-h-screen">
      <header className="sticky top-0 z-20 border-b border-white/10 bg-black/40 backdrop-blur">
        <div className="container-page py-4 flex items-center justify-between gap-4">
          <Link href="/vendor" className="font-semibold tracking-tight">
            Truvern <span className="text-white/60">Vendor Portal</span>
          </Link>

          <nav className="flex items-center gap-2">
            <Link className={clsx("btn-glass")} href="/vendor/requests">
              Evidence Requests
            </Link>
            <Link className={clsx("btn-glass")} href="/vendors">
              Back to Org App
            </Link>
          </nav>
        </div>
      </header>

      {children}

      <footer className="border-t border-white/10 mt-16">
        <div className="container-page py-8 text-sm text-white/60">
          This portal is for vendor evidence submissions and status tracking.
        </div>
      </footer>
    </div>
  );
}
