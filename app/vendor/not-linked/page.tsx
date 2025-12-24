// app/vendor/not-linked/page.tsx
import Link from "next/link";
import { resolveVendorPortalContext } from "@/lib/vendor-portal";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

function clsx(...parts: Array<string | false | null | undefined>) {
  return parts.filter(Boolean).join(" ");
}

export default async function VendorNotLinkedPage() {
  const ctx = await resolveVendorPortalContext();
  const signedIn = !!ctx.userId;

  return (
    <main className="container-page py-12">
      <div className="max-w-2xl glass-soft rounded-2xl border border-white/10 p-8">
        <h1 className="text-2xl font-semibold">Vendor Portal access not configured</h1>

        <p className="mt-2 text-white/70">
          {signedIn
            ? "You’re signed in, but this user isn’t linked to a vendor record in Truvern yet."
            : "You’re not signed in. Sign in with the vendor account to continue."}
        </p>

        <div className="mt-4 text-sm text-white/70 space-y-1">
          <div>
            Signed-in user id: <span className="font-mono text-white/90">{ctx.userId ?? "—"}</span>
          </div>
          <div>
            Selected Clerk org id:{" "}
            <span className="font-mono text-white/90">{ctx.selectedClerkOrgId ?? "—"}</span>
          </div>
          <div>
            Resolver error: <span className="font-mono text-white/90">{ctx.error ?? "—"}</span>
          </div>
        </div>

        {ctx.directLink ? (
          <div className="mt-4 rounded-xl border border-white/10 bg-white/5 p-4 text-sm text-white/80">
            <div className="font-medium text-white/90">A link exists in the database:</div>
            <pre className="mt-2 font-mono text-xs whitespace-pre-wrap break-words">
              {JSON.stringify(
                {
                  directLink: ctx.directLink,
                  directVendor: ctx.directVendor,
                  portalOrg: ctx.portalOrg,
                  vendorMatchesOrg: ctx.vendorMatchesOrg,
                },
                null,
                2
              )}
            </pre>
          </div>
        ) : null}

        <div className="mt-6 flex flex-wrap gap-2">
          {signedIn ? (
            <>
              {/* Clerk supports /sign-out in many setups; if yours differs, we’ll adjust */}
              <Link className={clsx("btn-glass")} href="/sign-out">
                Switch account
              </Link>
              <Link className={clsx("btn-glass")} href="/vendors">
                Back to Org App
              </Link>
              <Link className={clsx("btn-glass")} href="/vendor/debug">
                Vendor Debug
              </Link>
            </>
          ) : (
            <>
              <Link className={clsx("btn-primary")} href="/sign-in?redirect_url=/vendor">
                Sign in
              </Link>
              <Link className={clsx("btn-glass")} href="/">
                Home
              </Link>
            </>
          )}
        </div>

        <p className="mt-6 text-xs text-white/50">
          Admin note: create or update a <span className="font-mono">VendorPortalUser</span> row for this Clerk user id.
        </p>
      </div>
    </main>
  );
}
