import { Module } from '@nestjs/common';
import { DocumentNotesController } from './document-notes.controller';
import { DocumentNotesService } from './document-notes.service';

@Module({
  controllers: [DocumentNotesController],
  providers: [DocumentNotesService],
})
export class DocumentNotesModule {}
