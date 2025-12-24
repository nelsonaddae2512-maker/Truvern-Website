import Link from "next/link";
import prisma from "@/lib/prisma";
import { requireDbOrganization } from "@/lib/org-db";
import VendorEvidenceUploader from "@/components/vendor/vendor-evidence-uploader";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

function clsx(...parts: Array<string | false | null | undefined>) {
  return parts.filter(Boolean).join(" ");
}

function parseId(raw: unknown): number | null {
  const v = Array.isArray(raw) ? raw[0] : raw;
  const s = typeof v === "string" ? v.trim() : v == null ? "" : String(v);
  const n = Number(s);
  return Number.isFinite(n) ? n : null;
}

export default async function VendorPortalEvidencePage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  // Keep org context consistent with the rest of the app
  await requireDbOrganization();

  const { id } = await params;
  const vendorId = parseId(id);

  if (!vendorId) {
    return (
      <main className="container-page py-10">
        <h1 className="text-2xl font-semibold text-white">Invalid vendor id</h1>
        <div className="mt-4">
          <Link className="text-sky-300 hover:underline" href="/vendors">
            Back to Vendors
          </Link>
        </div>
      </main>
    );
  }

  // IMPORTANT:
  // Fetch requests server-side using the route vendorId.
  // Do NOT over-filter here — let the UI decide which statuses to show.
  const requests = await prisma.evidenceRequest.findMany({
    where: { vendorId },
    orderBy: [{ id: "desc" }],
    take: 200,
    select: {
      id: true,
      vendorId: true,
      label: true,
      status: true,
      description: true,
      createdAt: true,
    } as any,
  });

  const safeRequests = requests.map((r: any) => ({
    id: r.id,
    vendorId: r.vendorId,
    label: r.label ?? `Request #${r.id}`,
    status: String(r.status ?? ""),
    description: r.description ?? null,
    createdAt: r.createdAt ? new Date(r.createdAt).toISOString() : null,
  }));

  return (
    <main className="container-page py-10">
      <div className="flex items-start justify-between gap-4">
        <div>
          <h1 className="text-2xl font-semibold text-white">
            Vendor Portal — Evidence Upload
          </h1>
          <p className="mt-2 text-sm text-white/70">
            Upload evidence in response to a request. Requests are tied to a vendor and tracked for audit.
          </p>
        </div>

        <Link
          href={`/vendors/${vendorId}`}
          className={clsx("btn-glass")}
        >
          Back to Vendor
        </Link>
      </div>

      <div className="mt-8 glass-soft rounded-2xl p-5">
        <VendorEvidenceUploader vendorId={vendorId} initialRequests={safeRequests} />
      </div>
    </main>
  );
}
