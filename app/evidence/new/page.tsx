// app/evidence/new/page.tsx
import Link from "next/link";
import prisma from "@/lib/prisma";
import { requireDbOrganization } from "@/lib/org-db";
import NewEvidenceRequestForm from "@/components/evidence/new-evidence-request-form";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

export default async function NewEvidenceRequestPage({
  searchParams,
}: {
  searchParams?: Promise<Record<string, string | string[] | undefined>>;
}) {
  const org = await requireDbOrganization();
  const sp = (await searchParams) || {};
  const rawVendorId = Array.isArray(sp.vendorId) ? sp.vendorId[0] : sp.vendorId;
  const preselectVendorId = rawVendorId ? Number(rawVendorId) : null;

  const vendors = await prisma.vendor.findMany({
    where: { organizationId: org.id } as any,
    orderBy: [{ updatedAt: "desc" }, { id: "desc" }] as any,
    take: 500,
    select: { id: true, name: true } as any,
  });

  return (
    <main className="container-page py-10">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <h1 className="text-2xl font-semibold text-white">Request Evidence</h1>
          <p className="mt-1 text-sm text-white/70">
            Create an evidence request (SOC 2, ISO 27001, policies, etc.).
          </p>
        </div>

        <div className="flex items-center gap-2">
          <Link className="btn-glass" href="/evidence">
            Back to Evidence
          </Link>
        </div>
      </div>

      <section className="glass-soft mt-6 rounded-2xl p-4 sm:p-6">
        <NewEvidenceRequestForm
          vendors={vendors.map((v: any) => ({
            id: Number(v.id),
            name: String(v.name ?? `Vendor #${v.id}`),
          }))}
          preselectVendorId={
            Number.isFinite(preselectVendorId as any) ? (preselectVendorId as number) : undefined
          }
        />
      </section>
    </main>
  );
}
