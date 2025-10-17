/*
  Warnings:

  - You are about to drop the column `createdAt` on the `Vendor` table. All the data in the column will be lost.
  - You are about to drop the column `organizationId` on the `Vendor` table. All the data in the column will be lost.
  - You are about to drop the column `ownerId` on the `Vendor` table. All the data in the column will be lost.
  - You are about to drop the column `slug` on the `Vendor` table. All the data in the column will be lost.
  - You are about to drop the column `trustLevel` on the `Vendor` table. All the data in the column will be lost.
  - You are about to drop the column `trustScore` on the `Vendor` table. All the data in the column will be lost.
  - You are about to drop the column `trustUpdatedAt` on the `Vendor` table. All the data in the column will be lost.
  - You are about to drop the column `updatedAt` on the `Vendor` table. All the data in the column will be lost.
  - You are about to drop the `Answer` table. If the table is not empty, all the data it contains will be lost.
  - You are about to drop the `AssessmentSubmission` table. If the table is not empty, all the data it contains will be lost.
  - You are about to drop the `Evidence` table. If the table is not empty, all the data it contains will be lost.
  - You are about to drop the `Membership` table. If the table is not empty, all the data it contains will be lost.
  - You are about to drop the `Organization` table. If the table is not empty, all the data it contains will be lost.
  - You are about to drop the `PendingInvite` table. If the table is not empty, all the data it contains will be lost.
  - You are about to drop the `Usage` table. If the table is not empty, all the data it contains will be lost.
  - You are about to drop the `User` table. If the table is not empty, all the data it contains will be lost.
  - Added the required column `category` to the `Vendor` table without a default value. This is not possible if the table is not empty.
  - Added the required column `country` to the `Vendor` table without a default value. This is not possible if the table is not empty.
  - Added the required column `website` to the `Vendor` table without a default value. This is not possible if the table is not empty.

*/
-- DropForeignKey
ALTER TABLE "Answer" DROP CONSTRAINT "Answer_vendorId_fkey";

-- DropForeignKey
ALTER TABLE "Evidence" DROP CONSTRAINT "Evidence_vendorId_fkey";

-- DropForeignKey
ALTER TABLE "Membership" DROP CONSTRAINT "Membership_organizationId_fkey";

-- DropForeignKey
ALTER TABLE "Membership" DROP CONSTRAINT "Membership_userId_fkey";

-- DropForeignKey
ALTER TABLE "PendingInvite" DROP CONSTRAINT "PendingInvite_organizationId_fkey";

-- DropForeignKey
ALTER TABLE "Usage" DROP CONSTRAINT "Usage_organizationId_fkey";

-- DropForeignKey
ALTER TABLE "Vendor" DROP CONSTRAINT "Vendor_organizationId_fkey";

-- DropForeignKey
ALTER TABLE "Vendor" DROP CONSTRAINT "Vendor_ownerId_fkey";

-- DropIndex
DROP INDEX "Vendor_organizationId_idx";

-- DropIndex
DROP INDEX "Vendor_slug_key";

-- AlterTable
ALTER TABLE "Vendor" DROP COLUMN "createdAt",
DROP COLUMN "organizationId",
DROP COLUMN "ownerId",
DROP COLUMN "slug",
DROP COLUMN "trustLevel",
DROP COLUMN "trustScore",
DROP COLUMN "trustUpdatedAt",
DROP COLUMN "updatedAt",
ADD COLUMN     "category" TEXT NOT NULL,
ADD COLUMN     "country" TEXT NOT NULL,
ADD COLUMN     "website" TEXT NOT NULL;

-- DropTable
DROP TABLE "Answer";

-- DropTable
DROP TABLE "AssessmentSubmission";

-- DropTable
DROP TABLE "Evidence";

-- DropTable
DROP TABLE "Membership";

-- DropTable
DROP TABLE "Organization";

-- DropTable
DROP TABLE "PendingInvite";

-- DropTable
DROP TABLE "Usage";

-- DropTable
DROP TABLE "User";

-- DropEnum
DROP TYPE "EvidenceStatus";

-- DropEnum
DROP TYPE "Plan";

-- DropEnum
DROP TYPE "TrustLevel";
