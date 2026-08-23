import { Module } from '@nestjs/common';
import { RagIngestionService } from './rag-ingestion.service';
import { RagSearchService } from './rag-search.service';
import { EmbeddingService } from './embedding.service';
import { TextExtractionService } from './text-extraction.service';
import { RagSearchController } from './rag-search.controller';
import { AiProvidersModule } from '../ai/ai-providers.module';
import { StorageService } from '../common/storage/storage.service';

@Module({
  imports: [AiProvidersModule],
  controllers: [RagSearchController],
  providers: [RagIngestionService, RagSearchService, EmbeddingService, TextExtractionService, StorageService],
  // ÖNEMLİ: EmbeddingService önceden dışa aktarılmıyordu — sadece RagModule
  // içinde kullanılabiliyordu. KnowledgeBaseModule gibi başka modüllerin
  // de bu servisi kullanabilmesi için exports listesine eklendi.
  exports: [RagIngestionService, RagSearchService, EmbeddingService],
})
export class RagModule {}
