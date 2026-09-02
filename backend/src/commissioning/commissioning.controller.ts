import { Controller, Get, Post, Patch, Delete, Param, Body, UseGuards, UseInterceptors, UploadedFile, Req } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CommissioningService } from './commissioning.service';
import { Throttle } from '@nestjs/throttler';
import { AuthenticatedRequest } from '../common/types/authenticated-request';

@UseGuards(JwtAuthGuard)
@Controller('commissioning')
export class CommissioningController {
  constructor(private commissioningService: CommissioningService) {}

  @Get('template')
  getTemplate() {
    return this.commissioningService.getTemplate();
  }

  // Kullanıcı isteği: "Dijital Cihaz Pasaportu" — QR kod ile cihaz geçmişi.
  // /reports/:id'den ÖNCE tanımlanmalı, aksi halde Nest ':id' route'u
  // 'device' segmentini id sanıp yakalar.
  @Get('device/:qrCode')
  getByQrCode(@Param('qrCode') qrCode: string) {
    return this.commissioningService.getByQrCode(qrCode);
  }

  @Post('reports')
  create(@Req() req: AuthenticatedRequest, @Body() body: any) {
    return this.commissioningService.create(req.user.sub, body);
  }

  @Get('reports')
  list(@Req() req: AuthenticatedRequest) {
    return this.commissioningService.listForDealer(req.user.sub);
  }

  @Get('reports/:id')
  get(@Req() req: AuthenticatedRequest, @Param('id') id: string) {
    return this.commissioningService.get(id, req.user.sub);
  }

  @Patch('reports/:id')
  update(@Req() req: AuthenticatedRequest, @Param('id') id: string, @Body() body: any) {
    return this.commissioningService.update(id, req.user.sub, body);
  }

  @Delete('reports/:id')
  delete(@Req() req: AuthenticatedRequest, @Param('id') id: string) {
    return this.commissioningService.delete(id, req.user.sub);
  }

  @Post('reports/:id/signature')
  @Throttle({ default: { limit: 20, ttl: 60_000 } })
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: 5 * 1024 * 1024 } }))
  attachSignature(@Req() req: AuthenticatedRequest, @Param('id') id: string, @UploadedFile() file: Express.Multer.File) {
    return this.commissioningService.attachSignature(id, req.user.sub, file);
  }

  @Get('reports/:id/signature-url')
  getSignatureUrl(@Req() req: AuthenticatedRequest, @Param('id') id: string) {
    return this.commissioningService.getSignedSignatureUrl(id, req.user.sub);
  }
}
