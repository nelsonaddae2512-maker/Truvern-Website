// app/vendors/[id]/edit/page.tsx
import Link from "next/link";
import prisma from "@/lib/prisma";
import VendorEditForm from "@/components/vendor-edit-form";
import { requireDbOrganization } from "@/lib/org-db";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

type ParamsPromise = Promise<{ id: string }>;
type Props = { params: ParamsPromise };

export default async function VendorEditPage({ params }: Props) {
  const { id } = await params;
  const vendorId = Number(id);

  if (!Number.isFinite(vendorId)) {
    return (
      <main className="container-page py-10">
        <h1 className="text-2xl font-semibold text-slate-50">Invalid vendor id</h1>
        <p className="mt-2 text-sm text-slate-200/70">
          Return to{" "}
          <Link href="/vendors" className="underline">
            vendors
          </Link>
          .
        </p>
      </main>
    );
  }

  const org = await requireDbOrganization();
  const organizationId = org.id;

  // ✅ Allow archived vendors to load, but we’ll guard editing below
  const vendor = await prisma.vendor.findFirst({
    where: { id: vendorId, organizationId },
    select: {
      id: true,
      name: true,
      summary: true,
      category: true,
      tier: true,
      criticality: true,
      status: true,
      deletedAt: true,
    },
  });

  if (!vendor) {
    return (
      <main className="container-page py-10">
        <h1 className="text-2xl font-semibold text-slate-50">Vendor not found</h1>
        <p className="mt-2 text-sm text-slate-200/70">
          Return to{" "}
          <Link href="/vendors" className="underline">
            vendors
          </Link>
          .
        </p>
      </main>
    );
  }

  const isArchived = Boolean(vendor.deletedAt);

  return (
    <main className="container-page py-10 max-w-3xl">
      <div className="mb-6 flex items-center justify-between gap-3">
        <Link href={`/vendors/${vendor.id}`} className="text-sm text-slate-300 hover:text-slate-100">
          ← Back to vendor
        </Link>

        <Link
          href={isArchived ? "/vendors?view=archived" : "/vendors"}
          className="rounded-lg border border-white/10 bg-white/5 px-3 py-1.5 text-sm text-slate-50 hover:bg-white/10"
        >
          Vendors
        </Link>
      </div>

      <h1 className="text-2xl font-semibold text-slate-50">Edit Vendor</h1>
      <p className="mt-1 text-sm text-slate-200/70">
        Update details shown across Truvern, including the summary preview on the vendor list.
      </p>

      {isArchived ? (
        <div className="mt-6 rounded-3xl border border-amber-400/25 bg-amber-500/10 p-5">
          <div className="text-xs tracking-[0.28em] text-amber-200/70">ARCHIVED VENDOR</div>
          <h2 className="mt-2 text-lg font-semibold text-slate-50">Editing is disabled</h2>
          <p className="mt-2 text-sm text-amber-100/90">
            <span className="font-semibold">{vendor.name}</span> is archived. Restore the vendor to edit details.
          </p>

          <div className="mt-4 flex flex-wrap gap-2">
            <Link
              href={`/vendors/${vendor.id}`}
              className="rounded-xl border border-white/10 bg-white/5 px-4 py-2 text-sm font-semibold text-slate-50 hover:bg-white/10"
            >
              Back to vendor ↗
            </Link>
            <Link
              href="/vendors?view=archived"
              className="rounded-xl border border-amber-400/30 bg-amber-500/10 px-4 py-2 text-sm font-semibold text-amber-100 hover:bg-amber-500/15"
            >
              View archived list ↗
            </Link>
          </div>
        </div>
      ) : (
        <VendorEditForm
          vendorId={vendor.id}
          initial={{
            name: vendor.name,
            summary: vendor.summary ?? null,
            category: vendor.category ?? null,
            tier: (vendor.tier as any) ?? null,
            criticality: (vendor.criticality as any) ?? null,
            status: vendor.status ?? null,
          }}
        />
      )}
    </main>
  );
}
