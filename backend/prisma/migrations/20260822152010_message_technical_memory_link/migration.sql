-- DropForeignKey
ALTER TABLE "message_citations" DROP CONSTRAINT "message_citations_documentChunkId_fkey";

-- AlterTable
ALTER TABLE "messages" ADD COLUMN     "technicalMemoryId" TEXT;

-- AddForeignKey
ALTER TABLE "message_citations" ADD CONSTRAINT "message_citations_documentChunkId_fkey" FOREIGN KEY ("documentChunkId") REFERENCES "document_chunks"("id") ON DELETE CASCADE ON UPDATE CASCADE;
