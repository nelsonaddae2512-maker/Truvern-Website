const { PrismaClient } = require("@prisma/client");
const prisma = new PrismaClient();

async function main() {
  const vendors = await prisma.vendor.findMany({
    select: { id: true, contactEmail: true, contactName: true },
  });

  let created = 0;

  for (const v of vendors) {
    const email = (v.contactEmail || "").trim().toLowerCase();
    if (!email) continue;

    const already = await prisma.vendorContact.findFirst({
      where: { vendorId: v.id, email },
      select: { id: true },
    });
    if (already) continue;

    await prisma.vendorContact.create({
      data: {
        vendorId: v.id,
        email,
        name: v.contactName || null,
        isPrimary: true,
        role: "PRIMARY",
      },
    });
    created++;
  }

  console.log({ ok: true, created });
}

main()
  .catch(console.error)
  .finally(async () => prisma.$disconnect());
