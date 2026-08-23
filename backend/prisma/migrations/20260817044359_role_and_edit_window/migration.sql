-- AlterEnum
ALTER TYPE "UserRole" ADD VALUE 'SALES';

-- AlterTable
ALTER TABLE "messages" ADD COLUMN     "editedAt" TIMESTAMP(3);
