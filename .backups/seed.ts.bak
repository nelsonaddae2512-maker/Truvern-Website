/**
 * prisma/seed.ts
 * NOTE: Seeding is disabled in production.
 */
if (process.env.NODE_ENV === "production") {
  console.log("Seed skipped in production");
  process.exit(0);
}

import { PrismaClient } from "@prisma/client";
const prisma = new PrismaClient();

async function main() {
  // TODO: add any minimal dev seed you still need locally
  console.log("Dev seed ran (local only)");
}

main().finally(async () => {
  await prisma.$disconnect();
});
