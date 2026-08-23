import { Module } from '@nestjs/common';
import { AiController } from './ai.controller';
import { AiService } from './ai.service';
import { TechnicalMemoryService } from './technical-memory.service';
import { AiProvidersModule } from './ai-providers.module';
import { RagModule } from '../rag/rag.module';
import { ChatModule } from '../chat/chat.module';
import { KnowledgeBaseModule } from '../knowledge-base/knowledge-base.module';

@Module({
  imports: [AiProvidersModule, RagModule, ChatModule, KnowledgeBaseModule],
  controllers: [AiController],
  providers: [AiService, TechnicalMemoryService],
  exports: [AiService, TechnicalMemoryService],
})
export class AiModule {}
