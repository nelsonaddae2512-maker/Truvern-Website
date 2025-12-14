-- AlterEnum
-- This migration adds more than one value to an enum.
-- With PostgreSQL versions 11 and earlier, this is not possible
-- in a single migration. This can be worked around by creating
-- multiple migrations, each migration adding only one value to
-- the enum.


ALTER TYPE "QuestionType" ADD VALUE 'YES_NO';
ALTER TYPE "QuestionType" ADD VALUE 'NUMBER';
ALTER TYPE "QuestionType" ADD VALUE 'MULTIPLE_CHOICE';
ALTER TYPE "QuestionType" ADD VALUE 'FILE_UPLOAD';

-- DropForeignKey
ALTER TABLE "AssessmentQuestion" DROP CONSTRAINT "AssessmentQuestion_templateId_fkey";

-- AlterTable
ALTER TABLE "AssessmentQuestion" ADD COLUMN     "category" TEXT,
ADD COLUMN     "description" TEXT,
ADD COLUMN     "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
ALTER COLUMN "templateId" DROP NOT NULL;

-- AddForeignKey
ALTER TABLE "AssessmentQuestion" ADD CONSTRAINT "AssessmentQuestion_templateId_fkey" FOREIGN KEY ("templateId") REFERENCES "AssessmentTemplate"("id") ON DELETE SET NULL ON UPDATE CASCADE;
