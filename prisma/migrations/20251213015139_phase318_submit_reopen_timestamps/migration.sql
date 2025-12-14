-- AlterTable
ALTER TABLE "Assessment" ADD COLUMN     "archivedAt" TIMESTAMP(3),
ADD COLUMN     "reopenedAt" TIMESTAMP(3),
ADD COLUMN     "startedAt" TIMESTAMP(3),
ADD COLUMN     "submittedAt" TIMESTAMP(3);

-- AlterTable
ALTER TABLE "AssessmentAnswer" ALTER COLUMN "value" DROP NOT NULL;

-- AlterTable
ALTER TABLE "AssessmentQuestion" ALTER COLUMN "updatedAt" DROP DEFAULT;
