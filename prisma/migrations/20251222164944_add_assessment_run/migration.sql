-- CreateTable
CREATE TABLE "AssessmentRun" (
    "id" SERIAL NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "organizationId" INTEGER NOT NULL,
    "vendorId" INTEGER,
    "assessmentId" INTEGER,
    "status" TEXT NOT NULL DEFAULT 'IN_PROGRESS',
    "startedAt" TIMESTAMP(3),
    "completedAt" TIMESTAMP(3),

    CONSTRAINT "AssessmentRun_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "AssessmentRun_organizationId_id_idx" ON "AssessmentRun"("organizationId", "id");

-- CreateIndex
CREATE INDEX "AssessmentRun_organizationId_vendorId_idx" ON "AssessmentRun"("organizationId", "vendorId");

-- CreateIndex
CREATE INDEX "AssessmentRun_organizationId_assessmentId_idx" ON "AssessmentRun"("organizationId", "assessmentId");

-- CreateIndex
CREATE INDEX "AssessmentRun_status_idx" ON "AssessmentRun"("status");

-- AddForeignKey
ALTER TABLE "AssessmentRun" ADD CONSTRAINT "AssessmentRun_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "Organization"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AssessmentRun" ADD CONSTRAINT "AssessmentRun_vendorId_fkey" FOREIGN KEY ("vendorId") REFERENCES "Vendor"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AssessmentRun" ADD CONSTRAINT "AssessmentRun_assessmentId_fkey" FOREIGN KEY ("assessmentId") REFERENCES "Assessment"("id") ON DELETE SET NULL ON UPDATE CASCADE;
