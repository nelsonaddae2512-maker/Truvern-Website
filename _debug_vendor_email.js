const { PrismaClient } = require("@prisma/client");

const p = new PrismaClient();

(async () => {
  const rows = await p.vendor.findMany({
    take: 10,
    orderBy: { id: "desc" },
    select: { id: true, name: true, contactEmail: true },
  });
  console.log(rows);
  await p.$disconnect();
})();
