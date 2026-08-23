-- CreateEnum
CREATE TYPE "WalletDocumentCategory" AS ENUM ('ISG', 'CERTIFICATE', 'TRAINING', 'AUTHORIZATION', 'OTHER');

-- CreateTable
CREATE TABLE "wallet_documents" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "category" "WalletDocumentCategory" NOT NULL DEFAULT 'OTHER',
    "fileUrl" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "wallet_documents_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "wallet_documents_userId_category_idx" ON "wallet_documents"("userId", "category");

-- AddForeignKey
ALTER TABLE "wallet_documents" ADD CONSTRAINT "wallet_documents_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
