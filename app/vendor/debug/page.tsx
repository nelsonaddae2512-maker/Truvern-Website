// app/vendor/debug/page.tsx
import { resolveVendorPortalContext, requireVendorPortalContext } from "@/lib/vendor-portal";
import Link from "next/link";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

function clsx(...parts: Array<string | false | null | undefined>) {
  return parts.filter(Boolean).join(" ");
}

export default async function VendorDebugPage() {
  // We want debug to show the raw resolved context even if not linked.
  const ctx = await resolveVendorPortalContext();

  // Preserve prior behavior where page might have been redirecting;
  // now we just show info + the same redirect target.
  const required = await requireVendorPortalContext();

  const payload = {
    userId: ctx.userId,
    selectedClerkOrgId: ctx.selectedClerkOrgId,
    vendorMatchesOrg: ctx.vendorMatchesOrg,
    portalOrganizationId: ctx.portalOrganizationId,
    directLink: ctx.directLink,
    directVendor: ctx.directVendor,
    portalOrg: ctx.portalOrg,
    error: required.ok ? null : required.ctx.error || "NOT_LINKED",
    redirectTo: required.ok ? null : required.redirectTo,
  };

  return (
    <main className="container-page py-10">
      <div className="flex items-start justify-between gap-4">
        <div>
          <h1 className="text-2xl font-semibold">Vendor Debug</h1>
          <p className="text-sm text-white/70 mt-1">
            Debug view for vendor portal resolution (Clerk user → VendorPortalUser → vendor/org).
          </p>
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

      <div className="glass-soft mt-6 rounded-2xl border border-white/10 p-5">
        <pre className="text-xs whitespace-pre-wrap break-words leading-relaxed">
          {JSON.stringify(payload, null, 2)}
        </pre>
      </div>

      {!required.ok ? (
        <div className="mt-4 text-sm text-white/70">
          Resolver returned <span className="font-mono text-white/90">{required.ctx.error}</span>.{" "}
          <Link className="underline text-white" href="/vendor/not-linked">
            View not-linked page
          </Link>
          .
        </div>
      ) : (
        <div className="mt-4 text-sm text-white/70">
          ✅ Vendor portal context resolved. Try{" "}
          <Link className="underline text-white" href="/vendor">
            /vendor
          </Link>
          .
        </div>
      )}
    </main>
  );
}
