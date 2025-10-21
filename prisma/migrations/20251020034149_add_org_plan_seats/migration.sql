/*
  Warnings:

  - You are about to drop the column `plan` on the `Organization` table. All the data in the column will be lost.
  - You are about to drop the column `seats` on the `Organization` table. All the data in the column will be lost.
  - You are about to drop the `AssessmentSubmission` table. If the table is not empty, all the data it contains will be lost.
  - You are about to drop the `PendingInvite` table. If the table is not empty, all the data it contains will be lost.
  - You are about to drop the `Usage` table. If the table is not empty, all the data it contains will be lost.
  - You are about to drop the `Vendor` table. If the table is not empty, all the data it contains will be lost.

*/
-- AlterTable
ALTER TABLE "Organization" DROP COLUMN "plan",
DROP COLUMN "seats";

-- DropTable
DROP TABLE "public"."AssessmentSubmission";

-- DropTable
DROP TABLE "public"."PendingInvite";

-- DropTable
DROP TABLE "public"."Usage";

-- DropTable
DROP TABLE "public"."Vendor";

-- DropEnum
DROP TYPE "public"."Plan";
