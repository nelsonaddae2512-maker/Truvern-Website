// app/vendors/[id]/page.tsx
import prisma from "@/lib/prisma";
import Link from "next/link";

type PageProps = {
  params: {
    id: string;
  };
};

export default async function VendorDetailPage({ params }: PageProps) {
  const vendorId = Number(params.id);

  if (Number.isNaN(vendorId)) {
    return (
      <div className="p-6">
        <h1 className="text-2xl font-bold mb-4">Vendor not found</h1>
        <p className="mb-4 text-gray-400">
          The vendor id in the URL is not valid.
        </p>
        <Link href="/vendors" className="text-emerald-400 underline">
          Back to vendors
        </Link>
      </div>
    );
  }

  const vendor = await prisma.vendor.findUnique({
    where: { id: vendorId },
    include: {
      evidence: {
        orderBy: { createdAt: "desc" },
      },
    },
  });

  if (!vendor) {
    return (
      <div className="p-6">
        <h1 className="text-2xl font-bold mb-4">Vendor not found</h1>
        <p className="mb-4 text-gray-400">
          We couldn&apos;t find a vendor with id {vendorId}.
        </p>
        <Link href="/vendors" className="text-emerald-400 underline">
          Back to vendors
        </Link>
      </div>
    );
  }

  const riskScore =
    vendor.riskScore !== null && vendor.riskScore !== undefined
      ? vendor.riskScore
      : "—";

  return (
    <div className="p-6 space-y-8">
      {/* Header / summary */}
      <header className="space-y-2">
        <p className="text-sm text-emerald-400 uppercase tracking-wide">
          Vendor profile
        </p>
        <h1 className="text-3xl font-bold">{vendor.name}</h1>
        <p className="text-sm text-gray-400">
          Active vendor in your Truvern TPRM network.
        </p>

        <div className="mt-4 flex flex-wrap gap-4">
          <div className="rounded-lg border border-emerald-500/40 bg-black/30 px-4 py-3">
            <p className="text-xs text-gray-400 uppercase tracking-wide">
              Risk score
            </p>
            <p className="text-2xl font-semibold text-emerald-400">
              {riskScore}
            </p>
          </div>
          <div className="rounded-lg border border-gray-700 bg-black/30 px-4 py-3">
            <p className="text-xs text-gray-400 uppercase tracking-wide">
              Vendor ID
            </p>
            <p className="text-lg font-mono text-gray-200">#{vendor.id}</p>
          </div>
          <div className="rounded-lg border border-gray-700 bg-black/30 px-4 py-3">
            <p className="text-xs text-gray-400 uppercase tracking-wide">
              Created
            </p>
            <p className="text-sm text-gray-200">
              {new Date(vendor.createdAt).toLocaleString()}
            </p>
          </div>
        </div>

        <div className="mt-4">
          <Link href="/vendors" className="text-emerald-400 underline text-sm">
            ← Back to vendors
          </Link>
        </div>
      </header>

      {/* Evidence panel */}
      <section className="space-y-4">
        <div className="flex items-center justify-between">
          <h2 className="text-xl font-semibold">Evidence</h2>
          <span className="text-xs text-gray-400">
            {vendor.evidence.length} item
            {vendor.evidence.length === 1 ? "" : "s"}
          </span>
        </div>

        {vendor.evidence.length === 0 ? (
          <p className="text-gray-500 text-sm">
            No evidence uploaded for this vendor yet.
          </p>
        ) : (
          <div className="overflow-hidden rounded-xl border border-gray-800 bg-black/40">
            <table className="min-w-full text-sm">
              <thead className="bg-gray-900/70">
                <tr>
                  <th className="px-4 py-2 text-left text-xs font-semibold text-gray-400">
                    Title
                  </th>
                  <th className="px-4 py-2 text-left text-xs font-semibold text-gray-400">
                    Description
                  </th>
                  <th className="px-4 py-2 text-left text-xs font-semibold text-gray-400">
                    Added
                  </th>
                  <th className="px-4 py-2 text-right text-xs font-semibold text-gray-400">
                    Action
                  </th>
                </tr>
              </thead>
              <tbody>
                {vendor.evidence.map((item) => (
                  <tr
                    key={item.id}
                    className="border-t border-gray-800 hover:bg-gray-900/50"
                  >
                    <td className="px-4 py-3 align-top font-medium text-gray-100">
                      {item.title ?? `Evidence #${item.id}`}
                    </td>
                    <td className="px-4 py-3 align-top text-gray-400">
                      {item.description ?? "—"}
                    </td>
                    <td className="px-4 py-3 align-top text-gray-400 whitespace-nowrap">
                      {new Date(item.createdAt).toLocaleString()}
                    </td>
                    <td className="px-4 py-3 align-top text-right">
                      {item.fileUrl ? (
                        <a
                          href={item.fileUrl}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="text-emerald-400 hover:text-emerald-300 underline text-sm"
                        >
                          View / download
                        </a>
                      ) : (
                        <span className="text-gray-500 text-xs">No file</span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </div>
  );
}
