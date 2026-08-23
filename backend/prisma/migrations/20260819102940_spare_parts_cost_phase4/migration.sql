-- CreateEnum
CREATE TYPE "SparePartStatus" AS ENUM ('REQUESTED', 'APPROVED', 'ORDERED', 'DELIVERED', 'REJECTED');

-- CreateEnum
CREATE TYPE "TicketCostCategory" AS ENUM ('ENGINEER_TIME', 'SITE_VISIT', 'TRAVEL', 'ACCOMMODATION', 'SPARE_PART', 'LABOR');

-- CreateTable
CREATE TABLE "spare_part_requests" (
    "id" TEXT NOT NULL,
    "ticketId" TEXT NOT NULL,
    "partCode" TEXT,
    "partName" TEXT NOT NULL,
    "quantity" INTEGER NOT NULL DEFAULT 1,
    "status" "SparePartStatus" NOT NULL DEFAULT 'REQUESTED',
    "requestedById" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "spare_part_requests_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ticket_costs" (
    "id" TEXT NOT NULL,
    "ticketId" TEXT NOT NULL,
    "category" "TicketCostCategory" NOT NULL,
    "description" TEXT,
    "amount" DOUBLE PRECISION NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ticket_costs_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "spare_part_requests_ticketId_idx" ON "spare_part_requests"("ticketId");

-- CreateIndex
CREATE INDEX "ticket_costs_ticketId_idx" ON "ticket_costs"("ticketId");

-- AddForeignKey
ALTER TABLE "spare_part_requests" ADD CONSTRAINT "spare_part_requests_ticketId_fkey" FOREIGN KEY ("ticketId") REFERENCES "support_tickets"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "spare_part_requests" ADD CONSTRAINT "spare_part_requests_requestedById_fkey" FOREIGN KEY ("requestedById") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ticket_costs" ADD CONSTRAINT "ticket_costs_ticketId_fkey" FOREIGN KEY ("ticketId") REFERENCES "support_tickets"("id") ON DELETE CASCADE ON UPDATE CASCADE;
