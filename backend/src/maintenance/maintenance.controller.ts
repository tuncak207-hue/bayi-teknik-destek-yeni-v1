import { Controller, Get, Post, Patch, Delete, Param, Body, UseGuards, UseInterceptors, UploadedFile, Req } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { MaintenanceService } from './maintenance.service';

@UseGuards(JwtAuthGuard)
@Controller('maintenance')
export class MaintenanceController {
  constructor(private maintenanceService: MaintenanceService) {}

  @Get('records')
  list(@Req() req: any) {
    return this.maintenanceService.list(req.user.sub);
  }

  @Post('records')
  create(
    @Req() req: any,
    @Body() data: { siteName: string; systemDescription?: string; notes: string; performedAt?: string },
  ) {
    return this.maintenanceService.create(req.user.sub, data);
  }

  @Get('records/:id')
  get(@Req() req: any, @Param('id') id: string) {
    return this.maintenanceService.get(id, req.user.sub);
  }

  @Patch('records/:id')
  update(@Req() req: any, @Param('id') id: string, @Body() data: any) {
    return this.maintenanceService.update(id, req.user.sub, data);
  }

  @Post('records/:id/signature')
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: 5 * 1024 * 1024 } }))
  attachSignature(@Req() req: any, @Param('id') id: string, @UploadedFile() file: Express.Multer.File) {
    return this.maintenanceService.attachSignature(id, req.user.sub, file);
  }

  @Get('records/:id/signature-url')
  getSignatureUrl(@Req() req: any, @Param('id') id: string) {
    return this.maintenanceService.getSignedSignatureUrl(id, req.user.sub);
  }

  @Delete('records/:id')
  remove(@Req() req: any, @Param('id') id: string) {
    return this.maintenanceService.remove(id, req.user.sub);
  }
}
