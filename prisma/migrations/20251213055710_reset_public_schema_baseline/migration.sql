/*
  Warnings:

  - The `severity` column on the `Issue` table would be dropped and recreated. This will lead to data loss if there is data in the column.
  - The `status` column on the `Issue` table would be dropped and recreated. This will lead to data loss if there is data in the column.

*/
-- AlterTable
ALTER TABLE "Issue" ALTER COLUMN "updatedAt" SET DEFAULT CURRENT_TIMESTAMP,
DROP COLUMN "severity",
ADD COLUMN     "severity" "IssueSeverity" NOT NULL DEFAULT 'MEDIUM',
DROP COLUMN "status",
ADD COLUMN     "status" "IssueStatus" NOT NULL DEFAULT 'OPEN';

-- CreateIndex
CREATE INDEX "Issue_status_severity_idx" ON "Issue"("status", "severity");
