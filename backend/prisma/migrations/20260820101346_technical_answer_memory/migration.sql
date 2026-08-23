-- CreateTable
CREATE TABLE "technical_answer_memory" (
    "id" TEXT NOT NULL,
    "question" TEXT NOT NULL,
    "answerMarkdown" TEXT NOT NULL,
    "embedding" vector(1024),
    "productName" TEXT,
    "productModel" TEXT,
    "productSeries" TEXT,
    "citations" JSONB,
    "verifiedByEngineerId" TEXT,
    "lastVerifiedAt" TIMESTAMP(3),
    "needsReverification" BOOLEAN NOT NULL DEFAULT false,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "usageCount" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "technical_answer_memory_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "technical_answer_memory_productName_productModel_idx" ON "technical_answer_memory"("productName", "productModel");

-- CreateIndex
CREATE INDEX "technical_answer_memory_isActive_idx" ON "technical_answer_memory"("isActive");

-- AddForeignKey
ALTER TABLE "technical_answer_memory" ADD CONSTRAINT "technical_answer_memory_verifiedByEngineerId_fkey" FOREIGN KEY ("verifiedByEngineerId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
