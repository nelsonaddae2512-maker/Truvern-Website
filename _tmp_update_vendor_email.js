const { PrismaClient } = require("@prisma/client");
const p = new PrismaClient();

(async () => {
  await p.vendor.update({
    where: { id: 13 },
    data: {
      contactName: "Primary Contact",
      contactEmail: "vendor@example.com",
    },
  });

  const v = await p.vendor.findUnique({ where: { id: 13 } });
  console.log("UPDATED:", v?.contactName ?? null, v?.contactEmail ?? null);

  await p.$disconnect();
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
