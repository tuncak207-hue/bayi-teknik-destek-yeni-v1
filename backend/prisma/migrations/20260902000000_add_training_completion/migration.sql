-- Kullanıcı isteği: "eğitimi tamamlamak için 1 gün verelim, geri sayaç
-- işlesin, izleyen kişi tamamladım desin, süre biterse tamamlanmadı
-- bilgisi düşsün, admin kim izledi kim izlemedi bilsin." Admin, eğitim
-- eklerken bunu isteğe bağlı açabiliyor.

-- AlterTable
ALTER TABLE "training_contents" ADD COLUMN "requiresCompletion" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "training_contents" ADD COLUMN "deadlineHours" INTEGER NOT NULL DEFAULT 24;

-- CreateTable
CREATE TABLE "training_completions" (
    "id" TEXT NOT NULL,
    "trainingId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "completedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "training_completions_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "training_completions_trainingId_userId_key" ON "training_completions"("trainingId", "userId");

-- AddForeignKey
ALTER TABLE "training_completions" ADD CONSTRAINT "training_completions_trainingId_fkey" FOREIGN KEY ("trainingId") REFERENCES "training_contents"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "training_completions" ADD CONSTRAINT "training_completions_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
