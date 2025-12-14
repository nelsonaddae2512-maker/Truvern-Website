-- CreateTable
CREATE TABLE "VendorRiskAlert" (
    "id" SERIAL NOT NULL,
    "vendorId" INTEGER NOT NULL,
    "type" TEXT NOT NULL,
    "message" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "resolvedAt" TIMESTAMP(3),

    CONSTRAINT "VendorRiskAlert_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "VendorRiskAlert_vendorId_type_resolvedAt_idx" ON "VendorRiskAlert"("vendorId", "type", "resolvedAt");

-- AddForeignKey
ALTER TABLE "VendorRiskAlert" ADD CONSTRAINT "VendorRiskAlert_vendorId_fkey" FOREIGN KEY ("vendorId") REFERENCES "Vendor"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
