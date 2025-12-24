const { PrismaClient } = require("@prisma/client");

const p = new PrismaClient();

(async () => {
  const clerkUserId = "user_36WIoB3je8YVszuYhNA0AzPzxBYS";

  const link = await p.vendorPortalUser.findUnique({ where: { clerkUserId } });
  if (!link) throw new Error("No VendorPortalUser for " + clerkUserId);

  const vendor = await p.vendor.findUnique({
    where: { id: link.vendorId },
    select: { organizationId: true },
  });
  if (!vendor) throw new Error("Vendor not found: " + link.vendorId);

  const updated = await p.vendorPortalUser.update({
    where: { clerkUserId },
    data: { organizationId: vendor.organizationId },
  });

  console.log({ before: link, after: updated });
})()
  .catch((e) => {
    console.error(e);
    process.exitCode = 1;
  })
  .finally(async () => {
    await p.$disconnect();
  });
