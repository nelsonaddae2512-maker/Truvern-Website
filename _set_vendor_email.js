const { PrismaClient } = require("@prisma/client");

const p = new PrismaClient();

async function main() {
  await p.vendor.update({
    where: { id: 20 },
    data: {
      contactEmail: "security@dggdt.test",
      contactName: "Security Team",
    },
  });

  console.log("updated vendor 20");
}

main()
  .catch(console.error)
  .finally(async () => {
    await p.$disconnect();
  });
