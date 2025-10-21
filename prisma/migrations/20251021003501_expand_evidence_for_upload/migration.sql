/*
  Warnings:

  - Added the required column `filename` to the `Evidence` table without a default value. This is not possible if the table is not empty.
  - Added the required column `url` to the `Evidence` table without a default value. This is not possible if the table is not empty.

*/
-- AlterTable
ALTER TABLE "Evidence" ADD COLUMN     "filename" TEXT NOT NULL,
ADD COLUMN     "size" INTEGER,
ADD COLUMN     "url" TEXT NOT NULL,
ADD COLUMN     "vendor" TEXT;

-- CreateIndex
CREATE INDEX "Evidence_userId_idx" ON "Evidence"("userId");
