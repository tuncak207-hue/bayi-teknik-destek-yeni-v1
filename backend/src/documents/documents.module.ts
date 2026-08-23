import { Module } from '@nestjs/common';
import { DocumentsController } from './documents.controller';
import { DocumentsService } from './documents.service';
import { RagModule } from '../rag/rag.module';
import { StorageService } from '../common/storage/storage.service';
import { NotificationsModule } from '../notifications/notifications.module';
import { TechnicalMemoryService } from '../ai/technical-memory.service';

@Module({
  imports: [RagModule, NotificationsModule],
  controllers: [DocumentsController],
  providers: [DocumentsService, StorageService, TechnicalMemoryService],
  exports: [DocumentsService],
})
export class DocumentsModule {}
