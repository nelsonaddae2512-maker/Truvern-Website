import prisma from "@/lib/prisma";

export default async function VendorEvidencePage({
  params,
}: {
  params: { id: string };
}) {
  const vendorId = Number(params.id);

  if (isNaN(vendorId)) {
    return (
      <div className="p-6">
        <h1 className="text-2xl font-bold mb-4">Vendor Evidence</h1>
        <p className="text-red-600">Invalid vendor ID.</p>
      </div>
    );
  }

  const evidence = await prisma.evidence.findMany({
    where: { vendorId },
    orderBy: { createdAt: "desc" },
  });

  return (
    <div className="p-6">
      <h1 className="text-2xl font-bold mb-4">Vendor Evidence</h1>

      {evidence.length === 0 && (
        <p className="text-gray-500">No evidence uploaded yet.</p>
      )}

      <ul className="space-y-4">
        {evidence.map((item) => (
          <li key={item.id} className="border p-4 rounded-lg">
            <p className="font-semibold">{item.title ?? item.name}</p>

            {item.fileUrl && (
              <a
                href={item.fileUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="text-blue-600 underline"
              >
                View document
              </a>
            )}

            {item.description && (
              <p className="text-gray-700 mt-2">{item.description}</p>
            )}

            <p className="text-sm text-gray-500 mt-2">
              Added: {new Date(item.createdAt).toLocaleString()}
            </p>

            {item.note && (
              <p className="text-xs text-gray-400 mt-1 italic">{item.note}</p>
            )}
          </li>
        ))}
      </ul>
    </div>
  );
}
