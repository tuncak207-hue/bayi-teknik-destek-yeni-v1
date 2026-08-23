/*
  Warnings:

  - Added the required column `updatedAt` to the `commissioning_reports` table without a default value. This is not possible if the table is not empty.

*/
-- AlterTable
ALTER TABLE "commissioning_reports" ADD COLUMN     "customerName" TEXT,
ADD COLUMN     "signatureUrl" TEXT,
ADD COLUMN     "updatedAt" TIMESTAMP(3) NOT NULL;

-- CreateTable
CREATE TABLE "bom_lists" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "items" JSONB NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "bom_lists_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "bom_lists_userId_createdAt_idx" ON "bom_lists"("userId", "createdAt");

-- AddForeignKey
ALTER TABLE "bom_lists" ADD CONSTRAINT "bom_lists_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
