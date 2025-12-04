import prisma from "@/lib/prisma";

export default async function VendorEvidencePage({ params }) {
  const vendorId = Number(params.id);

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
            <p className="font-semibold">{item.name}</p>
            {item.url && (
              <a
                href={item.url}
                target="_blank"
                className="text-blue-600 underline"
              >
                View document
              </a>
            )}
            <p className="text-sm text-gray-500 mt-2">
              Added: {new Date(item.createdAt).toLocaleString()}
            </p>
          </li>
        ))}
      </ul>
    </div>
  );
}
