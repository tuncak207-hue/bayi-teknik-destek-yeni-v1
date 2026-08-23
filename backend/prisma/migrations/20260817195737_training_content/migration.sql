-- CreateEnum
CREATE TYPE "TrainingContentType" AS ENUM ('VIDEO', 'DOCUMENT');

-- CreateTable
CREATE TABLE "training_contents" (
    "id" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "type" "TrainingContentType" NOT NULL,
    "category" TEXT,
    "fileUrl" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "training_contents_pkey" PRIMARY KEY ("id")
);
