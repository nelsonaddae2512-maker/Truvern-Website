-- AlterTable
ALTER TABLE "Evidence" ADD COLUMN     "evidenceRequestId" INTEGER;

-- AlterTable
ALTER TABLE "EvidenceRequest" ADD COLUMN     "reviewedAt" TIMESTAMP(3),
ADD COLUMN     "submittedAt" TIMESTAMP(3);

-- CreateIndex
CREATE INDEX "Evidence_evidenceRequestId_idx" ON "Evidence"("evidenceRequestId");

-- AddForeignKey
ALTER TABLE "Evidence" ADD CONSTRAINT "Evidence_evidenceRequestId_fkey" FOREIGN KEY ("evidenceRequestId") REFERENCES "EvidenceRequest"("id") ON DELETE SET NULL ON UPDATE CASCADE;
