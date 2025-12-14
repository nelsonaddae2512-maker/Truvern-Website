// app/trust-network/page.tsx
import prisma from "@/lib/prisma";
import TrustNetworkClient from "@/components/trust-network-client";

export const dynamic = "force-dynamic";

export default async function TrustNetworkPage() {
  const vendors = await prisma.vendor.findMany({
    orderBy: { createdAt: "desc" },
    include: {
      _count: {
        select: {
          assessments: true,
          evidence: true,
        },
      },
    },
  });

  const liveCount = vendors.length;

  const avgHealth =
    vendors.length > 0
      ? Math.round(
          vendors.reduce((sum, v) => sum + (v.riskScore ?? 0), 0) /
            vendors.length
        )
      : 0;

  const evidenceItems = vendors.reduce(
    (sum, v) => sum + v._count.evidence,
    0
  );

  const stats = {
    liveCount,
    avgHealth,
    evidenceItems,
  };

  // Shape vendors for the client component
  const shapedVendors = vendors.map((v) => ({
    id: v.id,
    name: v.name,
    riskScore: v.riskScore,
    createdAt: v.createdAt.toISOString(),
    summary: (v as any).summary ?? null, // safe optional
    _count: {
      assessments: v._count.assessments,
      evidence: v._count.evidence,
    },
  }));

  return (
    <div className="px-4 py-8 sm:px-6 lg:px-8">
      <TrustNetworkClient vendors={shapedVendors} stats={stats} />
    </div>
  );
}
