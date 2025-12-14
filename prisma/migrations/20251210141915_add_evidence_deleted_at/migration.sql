-- DropIndex
DROP INDEX "Evidence_organizationId_vendorId_idx";

-- AlterTable
ALTER TABLE "Evidence" ADD COLUMN     "deletedAt" TIMESTAMP(3),
ALTER COLUMN "fileUrl" DROP NOT NULL;
