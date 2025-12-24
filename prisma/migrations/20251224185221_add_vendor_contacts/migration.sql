-- CreateEnum
CREATE TYPE "VendorContactRole" AS ENUM ('PRIMARY', 'SECURITY', 'COMPLIANCE', 'LEGAL', 'OTHER');

-- CreateTable
CREATE TABLE "VendorContact" (
    "id" SERIAL NOT NULL,
    "vendorId" INTEGER NOT NULL,
    "name" TEXT,
    "email" TEXT NOT NULL,
    "phone" TEXT,
    "role" "VendorContactRole" NOT NULL DEFAULT 'OTHER',
    "isPrimary" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "VendorContact_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "VendorContact_vendorId_idx" ON "VendorContact"("vendorId");

-- CreateIndex
CREATE INDEX "VendorContact_vendorId_isPrimary_idx" ON "VendorContact"("vendorId", "isPrimary");

-- CreateIndex
CREATE UNIQUE INDEX "VendorContact_vendorId_email_key" ON "VendorContact"("vendorId", "email");

-- AddForeignKey
ALTER TABLE "VendorContact" ADD CONSTRAINT "VendorContact_vendorId_fkey" FOREIGN KEY ("vendorId") REFERENCES "Vendor"("id") ON DELETE CASCADE ON UPDATE CASCADE;
