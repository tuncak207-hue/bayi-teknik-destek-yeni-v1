-- CreateTable
CREATE TABLE "training_suggestion_logs" (
    "id" TEXT NOT NULL,
    "dealerId" TEXT NOT NULL,
    "productName" TEXT NOT NULL,
    "suggestedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "training_suggestion_logs_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "training_suggestion_logs_dealerId_productName_key" ON "training_suggestion_logs"("dealerId", "productName");
