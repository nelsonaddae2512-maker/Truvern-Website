// app/vendors/[id]/findings/page.tsx
import Link from "next/link";
import prisma from "@/lib/prisma";
import VendorFindingsPanel from "@/components/vendor-findings-panel";

export const runtime = "nodejs";

export default async function VendorFindingsPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const vendorId = Number(id);

  if (!Number.isFinite(vendorId)) {
    return (
      <main className="container-page py-12">
        <h1 className="text-2xl font-semibold">Invalid vendor id</h1>
      </main>
    );
  }

  const vendor = await prisma.vendor.findUnique({
    where: { id: vendorId },
    select: { id: true, name: true },
  });

  if (!vendor) {
    return (
      <main className="container-page py-12">
        <h1 className="text-2xl font-semibold">Vendor not found</h1>
        <Link className="mt-4 inline-block underline" href="/vendors">
          Back to Vendors
        </Link>
      </main>
    );
  }

  return (
    <main className="container-page py-12">
      <div className="flex flex-col gap-2 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <div className="text-xs text-slate-400">Vendor Findings</div>
          <h1 className="mt-1 text-3xl font-semibold tracking-tight">
            {vendor.name}
          </h1>
        </div>

        <div className="flex gap-2">
          <Link
            href={`/vendors/${vendor.id}`}
            className="rounded-md border border-slate-800 bg-slate-900 px-3 py-2 text-sm text-slate-100 hover:bg-slate-800"
          >
            Back to Vendor
          </Link>
          <Link
            href="/issues"
            className="rounded-md border border-slate-800 bg-slate-900 px-3 py-2 text-sm text-slate-100 hover:bg-slate-800"
          >
            Global Issues
          </Link>
        </div>
      </div>

      <VendorFindingsPanel vendorId={vendor.id} />
    </main>
  );
}
