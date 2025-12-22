// app/assessment/new/[vendorId]/page.tsx
import Link from "next/link";
import prisma from "@/lib/prisma";
import { requireDbOrganization } from "@/lib/org-db";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

type ParamsPromise = Promise<{ vendorId: string }>;
type Props = { params: ParamsPromise };

export default async function NewAssessmentForVendorPage({ params }: Props) {
  const org = await requireDbOrganization();
  const { vendorId } = await params;
  const idNum = Number(vendorId);

  if (!Number.isFinite(idNum)) {
    return (
      <main className="container-page py-12">
        <p className="text-sm text-rose-300">Invalid vendor id.</p>
      </main>
    );
  }

  const vendor = await prisma.vendor.findFirst({
    where: { id: idNum, organizationId: org.id },
    select: { id: true, name: true, deletedAt: true },
  });

  if (!vendor) {
    return (
      <main className="container-page py-12">
        <p className="text-sm text-rose-300">Vendor not found.</p>
      </main>
    );
  }

  if (vendor.deletedAt) {
    return (
      <main className="container-page py-12">
        <div className="glass-soft max-w-2xl rounded-3xl border border-amber-400/25 bg-amber-500/10 p-6">
          <h1 className="text-xl font-semibold text-slate-50">
            Vendor is archived
          </h1>
          <p className="mt-2 text-sm text-amber-100/90">
            New assessments are disabled for archived vendors. Restore the vendor
            to continue.
          </p>

          <div className="mt-4 flex flex-wrap gap-2">
            <Link href={`/vendors/${vendor.id}`} className="btn-glass">
              Back to vendor <span aria-hidden>↗</span>
            </Link>
            <Link href="/vendors?view=archived" className="btn-glass">
              View archived list <span aria-hidden>↗</span>
            </Link>
          </div>
        </div>
      </main>
    );
  }

  // If you already have the real flow, mount it here.
  return (
    <main className="container-page py-12">
      <div className="mb-6">
        <Link href={`/vendors/${vendor.id}`} className="btn-glass">
          ← Back to vendor
        </Link>
      </div>

      <h1 className="text-2xl font-semibold text-slate-50">Start assessment</h1>
      <p className="mt-1 text-sm text-slate-200/70">
        Start a new assessment for{" "}
        <span className="font-semibold text-slate-50">{vendor.name}</span>.
      </p>

      <div className="glass-soft mt-6 rounded-2xl p-5 text-sm text-slate-200/80">
        Plug your assessment creation UI here (template select + create run).
      </div>
    </main>
  );
}
