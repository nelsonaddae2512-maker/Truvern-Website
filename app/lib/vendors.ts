import prisma from "@/lib/prisma";

export async function getVendor(id: string | number) {
  const numericId = Number(id);

  if (!Number.isFinite(numericId)) {
    return null;
  }

  return prisma.vendor.findUnique({
    where: { id: numericId },
    include: {
      documents: true,
      assessments: {
        orderBy: { createdAt: "desc" },
        take: 5,
      },
    },
  });
}

export async function getVendors() {
  return prisma.vendor.findMany({
    orderBy: { createdAt: "desc" },
  });
}
