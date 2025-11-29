// app/vendors/[id]/page.tsx
import Link from "next/link";
import { notFound } from "next/navigation";
import { prisma } from "@/lib/prisma";
import { EvidenceDeleteButton } from "@/app/components/EvidenceDeleteButton";

interface PageProps {
  params: { id: string };
}

export const metadata = {
  title: "Vendor | Truvern",
};

export default async function VendorDetailPage({ params }: PageProps) {
  const id = parseInt(params.id, 10);
  if (!Number.isInteger(id)) {
    return notFound();
  }

  let vendor:
    | (Awaited<
        ReturnType<typeof prisma.vendor.findUnique>
      > & { evidence?: any[] | null })
    | null = null;

  let evidenceError: string | null = null;

  try {
    // 🔑 NOTE: orderBy.createdAt instead of uploadedAt
    vendor = await prisma.vendor.findUnique({
      where: { id },
      include: {
        evidence: {
          orderBy: { createdAt: "desc" },
        },
      },
    });
  } catch (err: any) {
    console.error("[/vendors/[id]] ERROR loading evidence:", err);
    evidenceError =
      err?.message ?? "Evidence table is not available in this environment.";

    // Fallback vendor-only query so the page still renders
    vendor = await prisma.vendor.findUnique({
      where: { id },
      select: {
        id: true,
        name: true,
        riskScore: true,
      },
    });
  }

  if (!vendor) {
    return notFound();
  }

  const evidenceList = Array.isArray((vendor as any).evidence)
    ? ((vendor as any).evidence as any[])
    : [];

  return (
    <div className="mx-auto max-w-5xl px-4 py-12 space-y-8">
      {/* Header */}
      <header className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">
            {vendor.name}
          </h1>
          <p className="text-sm text-slate-400 mt-1">
            Vendor details and supporting evidence.
          </p>
        </div>
        <div className="text-right">
          <p className="text-xs uppercase text-slate-400">Risk score</p>
          <p className="text-xl font-semibold">
            {"riskScore" in vendor && vendor.riskScore !== null
              ? vendor.riskScore
              : "—"}
          </p>
        </div>
      </header>

      {/* Evidence header + upload CTA */}
      <div className="flex justify-between items-center">
        <h2 className="text-lg font-semibold">Evidence</h2>
        <Link
          href={`/vendor/upload?vendorId=${vendor.id}`}
          className="inline-flex items-center rounded-md bg-emerald-500 px-3 py-1.5 text-sm font-medium text-black hover:bg-emerald-400"
        >
          Upload evidence
        </Link>
      </div>

      {/* Error banner if evidence query failed */}
      {evidenceError && (
        <div className="rounded-xl border border-amber-500/40 bg-amber-950/30 p-4 mb-4">
          <p className="text-sm font-medium text-amber-200">
            Evidence is temporarily unavailable.
          </p>
          <p className="mt-1 text-xs text-amber-100/80">
            Technical detail: {evidenceError}
          </p>
        </div>
      )}

      {/* Empty state */}
      {!evidenceError && evidenceList.length === 0 && (
        <p className="text-sm text-slate-400">
          No evidence has been uploaded for this vendor yet.
        </p>
      )}

      {/* Evidence table */}
      {!evidenceError && evidenceList.length > 0 && (
        <div className="overflow-hidden rounded-xl border border-slate-800 bg-slate-950/70">
          <table className="min-w-full text-sm">
            <thead className="bg-slate-900/70 text-xs uppercase tracking-wide text-slate-400">
              <tr>
                <th className="px-4 py-2 text-left">File</th>
                <th className="px-4 py-2 text-left">Notes</th>
                <th className="px-4 py-2 text-right">Size</th>
                <th className="px-4 py-2 text-right">Uploaded</th>
                <th className="px-4 py-2 text-right">Actions</th>
              </tr>
            </thead>
            <tbody>
              {evidenceList.map((e: any) => (
                <tr
                  key={e.id}
                  className="border-t border-slate-800 hover:bg-slate-900/80"
                >
                  <td className="px-4 py-2">
                    <span className="text-emerald-400">
                      {e.fileName ?? e.filename ?? "Untitled file"}
                    </span>
                  </td>
                  <td className="px-4 py-2 max-w-xs text-xs text-slate-300">
                    {e.notes || "—"}
                  </td>
                  <td className="px-4 py-2 text-right text-xs text-slate-400">
                    {formatSize(e.size)}
                  </td>
                  <td className="px-4 py-2 text-right text-xs text-slate-400">
                    {e.createdAt
                      ? new Date(e.createdAt).toLocaleDateString()
                      : "—"}
                  </td>
                  <td className="px-4 py-2 text-right text-xs space-x-3">
                    {/* Download */}
                   {item.fileUrl ? (
  <a
    href={item.fileUrl}
    target="_blank"
    rel="noopener noreferrer"
    className="text-emerald-400 hover:underline"
  >
    Download
  </a>
) : (
  <span className="text-slate-500 text-sm">No file</span>
)}

                    {/* Delete */}
                    <EvidenceDeleteButton evidenceId={e.id} />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}

function formatSize(bytes: number | null | undefined): string {
  if (!bytes || bytes <= 0) return "0 B";
  const units = ["B", "KB", "MB", "GB"];
  let size = bytes;
  let unit = 0;
  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit++;
  }
  return `${size.toFixed(1)} ${units[unit]}`;
}
