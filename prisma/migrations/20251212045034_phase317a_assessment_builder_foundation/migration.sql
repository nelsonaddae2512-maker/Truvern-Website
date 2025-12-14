/*
  Warnings:

  - A unique constraint covering the columns `[code]` on the table `AssessmentTemplate` will be added. If there are existing duplicate values, this will fail.

*/
-- CreateEnum
CREATE TYPE "AssessmentQuestionType" AS ENUM ('TEXT', 'YES_NO', 'SELECT', 'MULTI_SELECT', 'NUMBER');

-- AlterTable
ALTER TABLE "AssessmentAnswer" ADD COLUMN     "updatedAt" TIMESTAMP(3),
ADD COLUMN     "valueJson" JSONB;

-- AlterTable
ALTER TABLE "AssessmentQuestion" ADD COLUMN     "key" TEXT,
ADD COLUMN     "options" JSONB,
ADD COLUMN     "required" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "richType" "AssessmentQuestionType",
ADD COLUMN     "sectionId" INTEGER;

-- AlterTable
ALTER TABLE "AssessmentTemplate" ADD COLUMN     "category" TEXT,
ADD COLUMN     "code" TEXT,
ADD COLUMN     "isActive" BOOLEAN NOT NULL DEFAULT true,
ADD COLUMN     "version" TEXT;

-- CreateTable
CREATE TABLE "AssessmentSection" (
    "id" SERIAL NOT NULL,
    "templateId" INTEGER NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "order" INTEGER NOT NULL DEFAULT 0,
    "weight" DOUBLE PRECISION,

    CONSTRAINT "AssessmentSection_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "AssessmentTemplate_code_key" ON "AssessmentTemplate"("code");

-- AddForeignKey
ALTER TABLE "AssessmentSection" ADD CONSTRAINT "AssessmentSection_templateId_fkey" FOREIGN KEY ("templateId") REFERENCES "AssessmentTemplate"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AssessmentQuestion" ADD CONSTRAINT "AssessmentQuestion_sectionId_fkey" FOREIGN KEY ("sectionId") REFERENCES "AssessmentSection"("id") ON DELETE SET NULL ON UPDATE CASCADE;
