import prisma from "@/lib/prisma";

type EvidenceTableProps = {
  vendorId: number;
};

function formatDate(value: Date | string | null | undefined) {
  if (!value) return "—";
  const d = typeof value === "string" ? new Date(value) : value;
  if (Number.isNaN(d.getTime())) return "—";
  return d.toLocaleDateString();
}

/**
 * Server component that lists uploaded evidence documents for a vendor.
 */
export default async function EvidenceTable({ vendorId }: EvidenceTableProps) {
  const documents = await prisma.evidence.findMany({
    where: { vendorId },
    orderBy: { uploadedAt: "desc" },
  });

  if (!documents.length) {
    return (
      <p className="text-sm text-slate-400">
        No evidence has been uploaded yet for this vendor.
      </p>
    );
  }

  return (
    <div className="overflow-x-auto rounded-md border border-slate-800 bg-slate-950/40">
      <table className="min-w-full text-sm">
        <thead className="bg-slate-900/60 border-b border-slate-800">
          <tr>
            <th className="px-3 py-2 text-left font-medium text-slate-300">
              Evidence type
            </th>
            <th className="px-3 py-2 text-left font-medium text-slate-300">
              Description
            </th>
            <th className="px-3 py-2 text-left font-medium text-slate-300">
              Uploaded
            </th>
          </tr>
        </thead>
        <tbody>
          {documents.map((doc) => (
            <tr key={doc.id} className="border-t border-slate-900/60">
              <td className="px-3 py-2 text-slate-100">
                {doc.type ?? "Other security evidence"}
              </td>
              <td className="px-3 py-2 text-slate-300">
                {doc.description ?? "No description provided."}
              </td>
              <td className="px-3 py-2 text-slate-300">
                {formatDate(doc.uploadedAt)}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
