-- CreateTable
CREATE TABLE "VendorShareToken" (
    "id" SERIAL NOT NULL,
    "vendorId" INTEGER NOT NULL,
    "token" TEXT NOT NULL,
    "expiresAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "VendorShareToken_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "VendorShareToken_token_key" ON "VendorShareToken"("token");

-- CreateIndex
CREATE INDEX "VendorShareToken_vendorId_idx" ON "VendorShareToken"("vendorId");

-- CreateIndex
CREATE INDEX "VendorShareToken_expiresAt_idx" ON "VendorShareToken"("expiresAt");

-- AddForeignKey
ALTER TABLE "VendorShareToken" ADD CONSTRAINT "VendorShareToken_vendorId_fkey" FOREIGN KEY ("vendorId") REFERENCES "Vendor"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
