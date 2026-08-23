import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Param,
  Body,
  UseGuards,
  UseInterceptors,
  UploadedFile,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard, Roles } from '../auth/guards/jwt-auth.guard';
import { DocumentsService } from './documents.service';
import { UploadDocumentDto } from './dto/upload-document.dto';

@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('documents')
export class DocumentsController {
  constructor(private documentsService: DocumentsService) {}

  @Get()
  list() {
    return this.documentsService.list();
  }

  @Get(':id')
  get(@Param('id') id: string) {
    return this.documentsService.get(id);
  }

  @Get(':id/signed-url')
  getSignedUrl(@Param('id') id: string) {
    return this.documentsService.getSignedFileUrl(id);
  }

  @Get(':id/versions/:versionId/signed-url')
  getSignedUrlForVersion(@Param('id') id: string, @Param('versionId') versionId: string) {
    return this.documentsService.getSignedUrlForVersion(id, versionId);
  }

  @Roles('ADMIN')
  @Post('upload')
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: 50 * 1024 * 1024 } })) // 50 MB sınırı
  upload(@Body() dto: UploadDocumentDto, @UploadedFile() file: Express.Multer.File) {
    return this.documentsService.upload(dto, file);
  }

  @Roles('ADMIN')
  @Delete(':id')
  delete(@Param('id') id: string) {
    return this.documentsService.delete(id);
  }

  @Roles('ADMIN')
  @Patch(':id')
  update(@Param('id') id: string, @Body() body: Partial<{ title: string; brand: string; model: string }>) {
    return this.documentsService.update(id, body);
  }
}
