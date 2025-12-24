/*
  Warnings:

  - Made the column `organizationId` on table `EvidenceRequest` required. This step will fail if there are existing NULL values in that column.
  - Made the column `requestedBy` on table `EvidenceRequest` required. This step will fail if there are existing NULL values in that column.

*/
-- DropForeignKey
ALTER TABLE "EvidenceRequest" DROP CONSTRAINT "EvidenceRequest_organizationId_fkey";

-- AlterTable
ALTER TABLE "EvidenceRequest" ALTER COLUMN "organizationId" SET NOT NULL,
ALTER COLUMN "requestedBy" SET NOT NULL;

-- AddForeignKey
ALTER TABLE "EvidenceRequest" ADD CONSTRAINT "EvidenceRequest_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "Organization"("id") ON DELETE CASCADE ON UPDATE CASCADE;
