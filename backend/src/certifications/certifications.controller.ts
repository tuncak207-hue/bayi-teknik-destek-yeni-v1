import { Controller, Get, Post, Delete, Param, Body, UseGuards, UseInterceptors, UploadedFile, Req } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CertificationsService } from './certifications.service';

@UseGuards(JwtAuthGuard)
@Controller('certifications')
export class CertificationsController {
  constructor(private certificationsService: CertificationsService) {}

  @Get()
  list(@Req() req: any) {
    return this.certificationsService.list(req.user.sub);
  }

  @Get('expiring-soon')
  expiringSoon(@Req() req: any) {
    return this.certificationsService.expiringSoon(req.user.sub);
  }

  @Post()
  create(@Req() req: any, @Body() data: { brand: string; title: string; issuedAt?: string; expiresAt?: string }) {
    return this.certificationsService.create(req.user.sub, data);
  }

  @Post(':id/document')
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: 10 * 1024 * 1024 } }))
  attachDocument(@Req() req: any, @Param('id') id: string, @UploadedFile() file: Express.Multer.File) {
    return this.certificationsService.attachDocument(id, req.user.sub, file);
  }

  @Get(':id/document-url')
  getDocumentUrl(@Req() req: any, @Param('id') id: string) {
    return this.certificationsService.getSignedDocumentUrl(id, req.user.sub);
  }

  @Delete(':id')
  remove(@Req() req: any, @Param('id') id: string) {
    return this.certificationsService.remove(id, req.user.sub);
  }
}
