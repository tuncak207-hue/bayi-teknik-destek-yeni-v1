-- CreateEnum
CREATE TYPE "VisitType" AS ENUM ('DEALER_VISIT', 'PROJECT_MEETING', 'PRODUCT_INTRO', 'TECHNICAL_MEETING', 'QUOTE_MEETING', 'TRAINING', 'COLLECTION', 'OTHER');

-- CreateEnum
CREATE TYPE "VisitTopic" AS ENUM ('NEW_PROJECT', 'EXISTING_PROJECT', 'PRODUCT_REQUEST', 'PRICE_QUOTE', 'TECHNICAL_SUPPORT', 'NEW_PRODUCT_INTRO', 'TRAINING', 'BUSINESS_DEVELOPMENT', 'GENERAL', 'OTHER');

-- CreateEnum
CREATE TYPE "VisitOutcome" AS ENUM ('POSITIVE', 'QUOTE_PENDING', 'PROJECT_CREATED', 'ORDER_PENDING', 'FOLLOW_UP_NEEDED', 'NEGATIVE', 'NOT_HAPPENED', 'OTHER');

-- CreateEnum
CREATE TYPE "ProjectType" AS ENUM ('HOTEL', 'HOSPITAL', 'MALL', 'FACTORY', 'SCHOOL', 'RESIDENTIAL', 'GOVERNMENT', 'OFFICE', 'OTHER');

-- CreateTable
CREATE TABLE "dealer_visits" (
    "id" TEXT NOT NULL,
    "salespersonId" TEXT NOT NULL,
    "dealerId" TEXT,
    "dealerNameFreeText" TEXT,
    "city" TEXT,
    "visitDate" TIMESTAMP(3) NOT NULL,
    "visitType" "VisitType" NOT NULL,
    "contactName" TEXT,
    "contactTitle" TEXT,
    "contactPhone" TEXT,
    "contactEmail" TEXT,
    "topic" "VisitTopic",
    "outcome" "VisitOutcome" NOT NULL,
    "notes" TEXT NOT NULL,
    "hasProject" BOOLEAN NOT NULL DEFAULT false,
    "projectName" TEXT,
    "projectType" "ProjectType",
    "estimatedAmount" DOUBLE PRECISION,
    "estimatedOrderDate" TIMESTAMP(3),
    "relatedProducts" TEXT,
    "competitorBrand" TEXT,
    "winProbability" INTEGER,
    "projectDescription" TEXT,
    "needsFollowUp" BOOLEAN NOT NULL DEFAULT false,
    "followUpDate" TIMESTAMP(3),
    "followUpAction" TEXT,
    "followUpOwner" TEXT,
    "followUpNote" TEXT,
    "followUpDone" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "dealer_visits_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "dealer_visit_files" (
    "id" TEXT NOT NULL,
    "visitId" TEXT NOT NULL,
    "fileName" TEXT NOT NULL,
    "fileKey" TEXT NOT NULL,
    "mimeType" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "dealer_visit_files_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "dealer_visits_salespersonId_visitDate_idx" ON "dealer_visits"("salespersonId", "visitDate");

-- CreateIndex
CREATE INDEX "dealer_visits_dealerId_visitDate_idx" ON "dealer_visits"("dealerId", "visitDate");

-- CreateIndex
CREATE INDEX "dealer_visits_needsFollowUp_followUpDate_idx" ON "dealer_visits"("needsFollowUp", "followUpDate");

-- AddForeignKey
ALTER TABLE "dealer_visits" ADD CONSTRAINT "dealer_visits_salespersonId_fkey" FOREIGN KEY ("salespersonId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "dealer_visits" ADD CONSTRAINT "dealer_visits_dealerId_fkey" FOREIGN KEY ("dealerId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "dealer_visit_files" ADD CONSTRAINT "dealer_visit_files_visitId_fkey" FOREIGN KEY ("visitId") REFERENCES "dealer_visits"("id") ON DELETE CASCADE ON UPDATE CASCADE;
