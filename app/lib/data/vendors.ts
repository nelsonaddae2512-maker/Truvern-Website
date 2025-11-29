import prisma from "@/lib/prisma"; // keep this if it already works elsewhere

export async function getVendor(id: string | number) {
  return prisma.vendor.findUnique({
    where: { id: Number(id) },
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
