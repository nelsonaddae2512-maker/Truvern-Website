// app/vendor/page.tsx
import Link from "next/link";
import { redirect } from "next/navigation";
import { requireVendorPortalContext } from "@/lib/vendor-portal";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

function clsx(...parts: Array<string | false | null | undefined>) {
  return parts.filter(Boolean).join(" ");
}

export default async function VendorPortalHomePage() {
  const res = await requireVendorPortalContext();
  if (!res.ok) redirect(res.redirectTo || "/vendor/not-linked");

  const { ctx } = res;
  const vendorName = (ctx.directVendor as any)?.name ?? "Vendor";
  const orgName = (ctx.portalOrg as any)?.name ?? "Organization";

  return (
    <main className="container-page py-10">
      <div className="flex items-start justify-between gap-4">
        <div>
          <h1 className="text-2xl font-semibold">Vendor Portal</h1>
          <p className="mt-1 text-sm text-white/70">
            Signed in as <span className="text-white/90">{vendorName}</span> · {orgName}
          </p>
          {!ctx.vendorMatchesOrg && ctx.selectedClerkOrgId ? (
            <p className="mt-2 text-xs text-amber-200/80">
              Heads up: your selected org doesn’t match the vendor portal org. Portal access still works (this is just informational).
            </p>
          ) : null}
        </div>

        <div className="flex gap-2">
          <Link className={clsx("btn-glass")} href="/vendor/evidence-requests">
            Evidence Requests
          </Link>
          <Link className={clsx("btn-glass")} href="/vendors">
            Back to Org App
          </Link>
        </div>
      </div>

      <div className="mt-6 grid gap-4 md:grid-cols-2">
        <Link
          href="/vendor/evidence-requests"
          className={clsx("glass-soft rounded-2xl border border-white/10 p-5 hover:border-white/20 transition")}
        >
          <div className="text-base font-medium">Evidence Requests</div>
          <div className="mt-1 text-sm text-white/70">
            View requests, upload evidence, and track review status.
          </div>
        </Link>

        <Link
          href="/vendor/debug"
          className={clsx("glass-soft rounded-2xl border border-white/10 p-5 hover:border-white/20 transition")}
        >
          <div className="text-base font-medium">Debug</div>
          <div className="mt-1 text-sm text-white/70">
            See how your vendor portal context is being resolved.
          </div>
        </Link>
      </div>

      <p className="mt-10 text-xs text-white/50">
        This portal is for vendor evidence submissions and status tracking.
      </p>
    </main>
  );
}
