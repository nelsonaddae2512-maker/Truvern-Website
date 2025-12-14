-- AlterTable
ALTER TABLE "Vendor" ADD COLUMN     "riskTrend30d" TEXT,
ADD COLUMN     "riskTrend90d" TEXT;

-- CreateTable
CREATE TABLE "VendorRiskSnapshot" (
    "id" SERIAL NOT NULL,
    "vendorId" INTEGER NOT NULL,
    "score" INTEGER,
    "takenAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "VendorRiskSnapshot_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "VendorRiskSnapshot_vendorId_takenAt_idx" ON "VendorRiskSnapshot"("vendorId", "takenAt");

-- AddForeignKey
ALTER TABLE "VendorRiskSnapshot" ADD CONSTRAINT "VendorRiskSnapshot_vendorId_fkey" FOREIGN KEY ("vendorId") REFERENCES "Vendor"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
