const { PrismaClient } = require("@prisma/client");
const prisma = new PrismaClient();

async function main() {
  const vendors = [
    {
      name: "Acme Compliance LLC",
      website: "https://acme.example",
      category: "Compliance",
      country: "US",
    },
    {
      name: "Nordic Trustworks",
      website: "https://trustworks.example",
      category: "Security",
      country: "SE",
    },
    {
      name: "Pearl Vendor Network",
      website: "https://pearl.example",
      category: "Procurement",
      country: "SG",
    },
  ];

  // Clear existing data first (optional)
  await prisma.vendor.deleteMany();

  // Insert all vendors in bulk
  await prisma.vendor.createMany({
    data: vendors,
  });

  console.log(`âœ… Seeded ${vendors.length} vendors.`);
}

main()
  .catch((e) => {
    console.error("âŒ Error seeding:", e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
