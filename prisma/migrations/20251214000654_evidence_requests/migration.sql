-- CreateEnum
CREATE TYPE "EvidenceRequestStatus" AS ENUM ('OPEN', 'SUBMITTED', 'APPROVED', 'REJECTED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "EvidenceRequestKind" AS ENUM ('SOC2', 'ISO27001', 'POLICY', 'PEN_TEST', 'BCP_DRP', 'DPIA', 'OTHER');

-- CreateTable
CREATE TABLE "EvidenceRequest" (
    "id" SERIAL NOT NULL,
    "vendorId" INTEGER NOT NULL,
    "organizationId" INTEGER,
    "requestedBy" TEXT,
    "kind" "EvidenceRequestKind" NOT NULL DEFAULT 'OTHER',
    "label" TEXT NOT NULL,
    "description" TEXT,
    "dueAt" TIMESTAMP(3),
    "status" "EvidenceRequestStatus" NOT NULL DEFAULT 'OPEN',
    "evidenceId" INTEGER,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "EvidenceRequest_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "EvidenceRequest_vendorId_status_idx" ON "EvidenceRequest"("vendorId", "status");

-- CreateIndex
CREATE INDEX "EvidenceRequest_organizationId_idx" ON "EvidenceRequest"("organizationId");

-- AddForeignKey
ALTER TABLE "EvidenceRequest" ADD CONSTRAINT "EvidenceRequest_vendorId_fkey" FOREIGN KEY ("vendorId") REFERENCES "Vendor"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "EvidenceRequest" ADD CONSTRAINT "EvidenceRequest_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "Organization"("id") ON DELETE SET NULL ON UPDATE CASCADE;
