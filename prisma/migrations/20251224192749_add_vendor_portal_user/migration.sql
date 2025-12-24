-- CreateTable
CREATE TABLE "VendorPortalUser" (
    "id" SERIAL NOT NULL,
    "organizationId" INTEGER NOT NULL,
    "vendorId" INTEGER NOT NULL,
    "clerkUserId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "VendorPortalUser_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "VendorPortalUser_clerkUserId_key" ON "VendorPortalUser"("clerkUserId");

-- CreateIndex
CREATE INDEX "VendorPortalUser_organizationId_idx" ON "VendorPortalUser"("organizationId");

-- CreateIndex
CREATE INDEX "VendorPortalUser_vendorId_idx" ON "VendorPortalUser"("vendorId");

-- AddForeignKey
ALTER TABLE "VendorPortalUser" ADD CONSTRAINT "VendorPortalUser_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "Organization"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "VendorPortalUser" ADD CONSTRAINT "VendorPortalUser_vendorId_fkey" FOREIGN KEY ("vendorId") REFERENCES "Vendor"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
