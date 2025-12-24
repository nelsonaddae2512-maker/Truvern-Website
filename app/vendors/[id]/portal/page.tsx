// app/vendors/[id]/portal/page.tsx
import Link from "next/link";
import { requireDbOrganization } from "@/lib/org-db";
import prisma from "@/lib/prisma";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

function parseVendorId(raw: unknown): number {
  const v = Array.isArray(raw) ? raw[0] : raw;
  const s = typeof v === "string" ? v.trim() : v == null ? "" : String(v);
  const m = s.match(/\d+/);
  return m ? Number(m[0]) : NaN;
}

export default async function VendorPortalPage({ params }: { params: Promise<{ id: string }> }) {
  const org = await requireDbOrganization();
  const { id } = await params;
  const vendorId = parseVendorId(id);

  if (!Number.isFinite(vendorId)) {
    return (
      <main className="container-page py-10">
        <h1 className="text-2xl font-semibold text-white">Invalid vendor id</h1>
        <div className="mt-4">
          <Link className="btn-glass" href="/vendors">
            Back to vendors
          </Link>
        </div>
      </main>
    );
  }

  const vendor = await prisma.vendor.findFirst({
    where: { id: vendorId, organizationId: (org as any).id } as any,
    select: { id: true, name: true } as any,
  });

  if (!vendor) {
    return (
      <main className="container-page py-10">
        <h1 className="text-2xl font-semibold text-white">Vendor not found</h1>
        <p className="mt-2 text-white/70">This vendor either doesn&apos;t exist or isn&apos;t in your organization.</p>
        <div className="mt-4">
          <Link className="btn-glass" href="/vendors">
            Back to vendors
          </Link>
        </div>
      </main>
    );
  }

  return (
    <main className="container-page py-10">
      <div className="flex flex-col gap-2 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <h1 className="text-2xl font-semibold text-white">Vendor Portal</h1>
          <p className="mt-1 text-sm text-white/70">
            Vendor: <span className="text-white/90">{vendor.name}</span>
          </p>
        </div>

        <div className="flex items-center gap-2">
          <Link className="btn-glass" href={`/vendors/${vendorId}`}>
            Back to Vendor
          </Link>
          <Link className="btn-primary" href={`/vendors/${vendorId}/portal/evidence`}>
            Upload Evidence
          </Link>
        </div>
      </div>

      <section className="glass-soft mt-6 rounded-2xl p-5 sm:p-6">
        <div className="text-white/90 font-medium">Evidence Submission</div>
        <p className="mt-1 text-sm text-white/70">
          Upload requested documents (SOC 2, ISO 27001, policies, etc.) for review.
        </p>

        <div className="mt-4 flex flex-wrap gap-2">
          <Link className="btn-primary" href={`/vendors/${vendorId}/portal/evidence`}>
            Go to Evidence Upload
          </Link>
          <Link className="btn-glass" href="/evidence">
            Evidence Hub
          </Link>
        </div>
      </section>
    </main>
  );
}
