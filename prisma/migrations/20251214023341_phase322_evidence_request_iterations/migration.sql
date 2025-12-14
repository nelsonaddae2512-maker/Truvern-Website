-- AlterTable
ALTER TABLE "Evidence" ADD COLUMN     "iterationId" INTEGER;

-- CreateTable
CREATE TABLE "EvidenceRequestIteration" (
    "id" SERIAL NOT NULL,
    "evidenceRequestId" INTEGER NOT NULL,
    "status" "EvidenceRequestStatus" NOT NULL DEFAULT 'SUBMITTED',
    "submittedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "submittedBy" TEXT,
    "reviewerNote" TEXT,
    "reviewedAt" TIMESTAMP(3),

    CONSTRAINT "EvidenceRequestIteration_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "EvidenceRequestIteration_evidenceRequestId_submittedAt_idx" ON "EvidenceRequestIteration"("evidenceRequestId", "submittedAt");

-- CreateIndex
CREATE INDEX "Evidence_iterationId_idx" ON "Evidence"("iterationId");

-- AddForeignKey
ALTER TABLE "EvidenceRequestIteration" ADD CONSTRAINT "EvidenceRequestIteration_evidenceRequestId_fkey" FOREIGN KEY ("evidenceRequestId") REFERENCES "EvidenceRequest"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Evidence" ADD CONSTRAINT "Evidence_iterationId_fkey" FOREIGN KEY ("iterationId") REFERENCES "EvidenceRequestIteration"("id") ON DELETE SET NULL ON UPDATE CASCADE;
