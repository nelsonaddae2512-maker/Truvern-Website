const { PrismaClient } = require("@prisma/client");
const p = new PrismaClient();

(async () => {
  const v = await p.vendor.findUnique({
    where: { id: 20 },
    select: { id: true, name: true, contactEmail: true },
  });
  console.log(v);
  await p.$disconnect();
})();
