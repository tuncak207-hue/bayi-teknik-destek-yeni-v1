import { Controller, Get, Post, Delete, Param, Body, UseGuards, Req } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { DocumentNotesService } from './document-notes.service';

@UseGuards(JwtAuthGuard)
@Controller('documents/:documentId/notes')
export class DocumentNotesController {
  constructor(private notesService: DocumentNotesService) {}

  @Get()
  list(@Param('documentId') documentId: string) {
    return this.notesService.list(documentId);
  }

  @Post()
  create(@Req() req: any, @Param('documentId') documentId: string, @Body('content') content: string) {
    return this.notesService.create(documentId, req.user.sub, content);
  }

  @Delete(':noteId')
  remove(@Req() req: any, @Param('noteId') noteId: string) {
    return this.notesService.remove(noteId, req.user.sub);
  }
}
