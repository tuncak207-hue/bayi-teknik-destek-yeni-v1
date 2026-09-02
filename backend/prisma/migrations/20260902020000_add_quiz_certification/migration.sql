-- Kullanıcı isteği: "AI Sınav/Sertifikasyon Motoru" — eğitim içeriğinden
-- AI'nin ürettiği sorular ve kullanıcıların sınav denemeleri.

-- AlterTable
ALTER TABLE "training_contents" ADD COLUMN "quizQuestions" JSONB;

-- CreateTable
CREATE TABLE "training_quiz_attempts" (
    "id" TEXT NOT NULL,
    "trainingId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "score" INTEGER NOT NULL,
    "passed" BOOLEAN NOT NULL,
    "completedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "training_quiz_attempts_pkey" PRIMARY KEY ("id")
);

-- AddForeignKey
ALTER TABLE "training_quiz_attempts" ADD CONSTRAINT "training_quiz_attempts_trainingId_fkey" FOREIGN KEY ("trainingId") REFERENCES "training_contents"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "training_quiz_attempts" ADD CONSTRAINT "training_quiz_attempts_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
