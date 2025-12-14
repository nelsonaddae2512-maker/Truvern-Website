/*
  Warnings:

  - Added the required column `updatedAt` to the `Issue` table without a default value. This is not possible if the table is not empty.
  - Changed the type of `severity` on the `Issue` table. No cast exists, the column would be dropped and recreated, which cannot be done if there is data, since the column is required.
  - Changed the type of `status` on the `Issue` table. No cast exists, the column would be dropped and recreated, which cannot be done if there is data, since the column is required.

*/
-- AlterTable
ALTER TABLE "Issue" ADD COLUMN     "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
ADD COLUMN     "dueAt" TIMESTAMP(3),
ADD COLUMN     "updatedAt" TIMESTAMP(3) NOT NULL,
DROP COLUMN "severity",
ADD COLUMN     "severity" TEXT NOT NULL,
DROP COLUMN "status",
ADD COLUMN     "status" TEXT NOT NULL;

-- CreateTable
CREATE TABLE "IssueEvent" (
    "id" SERIAL NOT NULL,
    "issueId" INTEGER NOT NULL,
    "type" TEXT NOT NULL,
    "payload" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "IssueEvent_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "IssueEvent_issueId_createdAt_idx" ON "IssueEvent"("issueId", "createdAt");

-- CreateIndex
CREATE INDEX "Issue_status_severity_idx" ON "Issue"("status", "severity");

-- CreateIndex
CREATE INDEX "Issue_dueAt_idx" ON "Issue"("dueAt");

-- AddForeignKey
ALTER TABLE "IssueEvent" ADD CONSTRAINT "IssueEvent_issueId_fkey" FOREIGN KEY ("issueId") REFERENCES "Issue"("id") ON DELETE CASCADE ON UPDATE CASCADE;
