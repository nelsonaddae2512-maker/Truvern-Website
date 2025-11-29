import { PrismaClient } from '@prisma/client'
const prisma = new PrismaClient()

async function main() {
  await prisma.vendor.createMany({
    data: [
      { name: "Stripe Services", riskScore: 55 },
      { name: "Samsara", riskScore: 70 },
      { name: "Geotab Inc", riskScore: 68 }
    ],
    skipDuplicates: true
  })
}

main()
  .catch(e => {
    console.error(e)
    process.exit(1)
  })
  .finally(async () => {
    await prisma.$disconnect()
  })
