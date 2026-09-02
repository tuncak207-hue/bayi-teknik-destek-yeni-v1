import { Controller, Get, Post, Patch, Delete, Param, Body, UseGuards, UseInterceptors, UploadedFile, Req } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CommissioningService } from './commissioning.service';

@UseGuards(JwtAuthGuard)
@Controller('commissioning')
export class CommissioningController {
  constructor(private commissioningService: CommissioningService) {}

  @Get('template')
  getTemplate() {
    return this.commissioningService.getTemplate();
  }

  @Post('reports')
  create(@Req() req: any, @Body() body: any) {
    return this.commissioningService.create(req.user.sub, body);
  }

  @Get('reports')
  list(@Req() req: any) {
    return this.commissioningService.listForDealer(req.user.sub);
  }

  @Get('reports/:id')
  get(@Req() req: any, @Param('id') id: string) {
    return this.commissioningService.get(id, req.user.sub);
  }

  @Patch('reports/:id')
  update(@Req() req: any, @Param('id') id: string, @Body() body: any) {
    return this.commissioningService.update(id, req.user.sub, body);
  }

  @Delete('reports/:id')
  delete(@Req() req: any, @Param('id') id: string) {
    return this.commissioningService.delete(id, req.user.sub);
  }

  @Post('reports/:id/signature')
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: 5 * 1024 * 1024 } }))
  attachSignature(@Req() req: any, @Param('id') id: string, @UploadedFile() file: Express.Multer.File) {
    return this.commissioningService.attachSignature(id, req.user.sub, file);
  }

  @Get('reports/:id/signature-url')
  getSignatureUrl(@Req() req: any, @Param('id') id: string) {
    return this.commissioningService.getSignedSignatureUrl(id, req.user.sub);
  }
}
