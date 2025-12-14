// app/trust-network/vendor/[id]/page.tsx
import prisma from "@/lib/prisma";
import { notFound } from "next/navigation";

type PageProps = {
  // On your setup, params is a Promise (same as /vendors/[id])
  params: Promise<{ id: string }>;
};

export default async function PublicVendorTrustPage({ params }: PageProps) {
  const { id } = await params;
  const numericId = Number(id);

  if (!id || Number.isNaN(numericId)) {
    notFound();
  }

  const vendor = await prisma.vendor.findUnique({
    where: { id: numericId },
  });

  if (!vendor) {
    notFound();
  }

  const createdAt =
    vendor.createdAt instanceof Date
      ? vendor.createdAt
      : // @ts-ignore Prisma type vs runtime
        new Date(vendor.createdAt as any);

  // This uses the same global layout/header as marketing
  return (
    <main className="mx-auto min-h-screen max-w-4xl px-6 py-12 text-slate-900">
      <section className="mb-8 rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
        <p className="mb-2 text-[11px] font-medium uppercase tracking-wide text-emerald-600">
          Truvern Trust Profile
        </p>
        <h1 className="mb-1 text-2xl font-semibold text-slate-900">
          {vendor.name}
        </h1>
        <p className="text-sm text-slate-500">
          Created {createdAt.toLocaleDateString()}
          {typeof vendor.riskScore === "number"
            ? ` · Risk score ${vendor.riskScore}`
            : ""}
        </p>

        <div className="mt-4 rounded-xl border border-slate-100 bg-slate-50 px-4 py-3">
          <h2 className="mb-1 text-sm font-semibold text-slate-900">
            Overview
          </h2>
          <p className="text-xs leading-snug text-slate-600">
            This read-only page is a public Truvern Trust Profile for{" "}
            <span className="font-medium">{vendor.name}</span>. It is intended
            for customers, auditors, and partners who received this secure link
            from the vendor&apos;s security team.
          </p>
        </div>
      </section>

      {/* You can expand this later with CIA rollups, evidence counts, etc. */}
      <section className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
        <h2 className="mb-2 text-sm font-semibold text-slate-900">
          Security posture snapshot
        </h2>
        <p className="text-xs text-slate-600">
          Additional details about certifications, assessments, and evidence can
          be surfaced here as your Truvern workspace evolves.
        </p>
      </section>
    </main>
  );
}
