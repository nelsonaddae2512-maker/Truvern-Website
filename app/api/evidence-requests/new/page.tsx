import Link from "next/link";
import prisma from "@/lib/prisma";
import EvidenceRequestForm from "@/components/evidence-request-form";

type ParamsPromise = Promise<{ id: string }>;

export default async function NewEvidenceRequestPage({ params }: { params: ParamsPromise }) {
  const { id } = await params;
  const vendorId = Number(id);

  if (!Number.isFinite(vendorId)) {
    return (
      <main className="max-w-4xl mx-auto px-4 py-12">
        <p className="text-sm text-rose-300">Invalid vendor id.</p>
      </main>
    );
  }

  const vendor = await prisma.vendor.findUnique({
    where: { id: vendorId },
    select: { id: true, name: true, organizationId: true },
  });

  if (!vendor) {
    return (
      <main className="max-w-4xl mx-auto px-4 py-12">
        <p className="text-sm text-rose-300">Vendor not found.</p>
      </main>
    );
  }

  return (
    <main className="max-w-5xl mx-auto px-4 py-10">
      <div className="flex items-center justify-between gap-3">
        <div>
          <div className="text-xs tracking-[0.25em] text-emerald-200/80">EVIDENCE REQUEST</div>
          <h1 className="mt-2 text-3xl font-semibold text-slate-50">
            Request evidence from {vendor.name}
          </h1>
          <p className="mt-2 text-sm text-slate-200/70">
            Create a request the vendor will see in their Task Inbox.
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
        <EvidenceRequestForm vendorId={vendor.id} organizationId={vendor.organizationId ?? null} />
      </div>
    </main>
  );
}
