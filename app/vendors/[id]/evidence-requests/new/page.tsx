// app/vendors/[id]/evidence-requests/new/page.tsx
import Link from "next/link";
import prisma from "@/lib/prisma";
import EvidenceRequestForm from "@/components/evidence-request-form";
import { requireDbOrganization } from "@/lib/org-db";

type ParamsPromise = Promise<{ id: string }>;

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

export default async function NewEvidenceRequestPage({
  params,
}: {
  params: ParamsPromise;
}) {
  const org = await requireDbOrganization();

  const { id } = await params;
  const vendorId = Number(id);

  if (!Number.isFinite(vendorId)) {
    return (
      <main className="max-w-4xl mx-auto px-4 py-12">
        <p className="text-sm text-rose-300">Invalid vendor id.</p>
      </main>
    );
  }

  // ✅ Org-scoped + includes deletedAt so we can block archived vendors
  const vendor = await prisma.vendor.findFirst({
    where: { id: vendorId, organizationId: org.id },
    select: { id: true, name: true, organizationId: true, deletedAt: true },
  });

  if (!vendor) {
    return (
      <main className="max-w-4xl mx-auto px-4 py-12">
        <p className="text-sm text-rose-300">Vendor not found.</p>
      </main>
    );
  }

  // ✅ Phase 326E: guardrail — block evidence requests for archived vendors
  if (vendor.deletedAt) {
    return (
      <main className="max-w-4xl mx-auto px-4 py-12">
        <div className="rounded-3xl border border-amber-400/25 bg-amber-500/10 p-6">
          <div className="text-xs tracking-[0.28em] text-amber-200/70">
            ARCHIVED VENDOR
          </div>
          <h1 className="mt-2 text-2xl font-semibold text-slate-50">
            Evidence requests are disabled
          </h1>
          <p className="mt-2 text-sm text-amber-100/90">
            <span className="font-semibold">{vendor.name}</span> is archived. Restore the vendor to create new evidence requests.
          </p>

          <div className="mt-4 flex flex-wrap gap-2">
            <Link
              href={`/vendors/${vendor.id}`}
              className="rounded-full border border-white/10 bg-white/5 px-4 py-2 text-sm font-medium text-slate-100 hover:bg-white/10"
            >
              Back to vendor ↗
            </Link>

            <Link
              href="/vendors?view=archived"
              className="rounded-full border border-amber-400/30 bg-amber-500/10 px-4 py-2 text-sm font-medium text-amber-100 hover:bg-amber-500/15"
            >
              View archived list ↗
            </Link>
          </div>
        </div>
      </main>
    );
  }

  return (
    <main className="relative max-w-5xl mx-auto px-4 lg:px-6 py-12 lg:py-16">
      <div className="pointer-events-none absolute inset-x-0 -top-32 -z-10 h-64 bg-[radial-gradient(circle_at_top,_rgba(45,212,191,0.18),transparent_60%)]" />

      <div className="flex items-start justify-between gap-4">
        <div>
          <div className="text-xs tracking-[0.28em] text-emerald-200/70">
            EVIDENCE REQUEST
          </div>
          <h1 className="mt-2 text-3xl font-semibold text-slate-50">
            Request evidence from {vendor.name}
          </h1>
          <p className="mt-2 text-sm text-slate-200/70">
            Create a vendor-facing request that appears as an action item in Vendor Portal.
          </p>
        </div>

        <Link
          href={`/vendors/${vendor.id}`}
          className="rounded-full border border-white/10 bg-white/5 px-4 py-2 text-sm font-medium text-slate-100 hover:bg-white/10"
        >
          Back to vendor ↗
        </Link>
      </div>

      <div className="mt-8 rounded-2xl border border-white/10 bg-slate-950/40 p-5">
        <EvidenceRequestForm
          vendorId={vendor.id}
          organizationId={vendor.organizationId ?? null}
          onCreatedHref={`/vendors/${vendor.id}`}
        />
      </div>
    </main>
  );
}
