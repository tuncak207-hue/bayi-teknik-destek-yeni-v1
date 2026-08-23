import { Controller, Get, Post, Patch, Delete, Param, Body, Query, UseGuards, UseInterceptors, UploadedFile, Req } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard, Roles } from '../auth/guards/jwt-auth.guard';
import { DealerVisitsService } from './dealer-visits.service';

// Not: sadece ADMIN ve SALES rolleri bu modüle erişebilir — bayiler ve
// mühendisler için ilgisiz bir modül.
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('dealer-visits')
export class DealerVisitsController {
  constructor(private visitsService: DealerVisitsService) {}

  @Roles('ADMIN', 'SALES')
  @Get()
  list(@Req() req: any, @Query() query: any) {
    const isAdmin = req.user.role === 'ADMIN';
    return this.visitsService.list(req.user.sub, isAdmin, query);
  }

  @Roles('ADMIN')
  @Get('dashboard-summary')
  dashboardSummary() {
    return this.visitsService.dashboardSummary();
  }

  @Roles('ADMIN', 'SALES')
  @Get('salesperson/:id/performance')
  salespersonPerformance(@Param('id') id: string) {
    return this.visitsService.salespersonPerformance(id);
  }

  @Roles('ADMIN', 'SALES')
  @Get('dealer/:id/history')
  dealerHistory(@Param('id') id: string) {
    return this.visitsService.dealerHistory(id);
  }

  @Roles('ADMIN', 'SALES')
  @Get(':id')
  get(@Req() req: any, @Param('id') id: string) {
    const isAdmin = req.user.role === 'ADMIN';
    return this.visitsService.get(id, req.user.sub, isAdmin);
  }

  @Roles('ADMIN', 'SALES')
  @Post()
  create(@Req() req: any, @Body() body: any) {
    return this.visitsService.create(req.user.sub, body);
  }

  @Roles('ADMIN', 'SALES')
  @Patch(':id')
  update(@Req() req: any, @Param('id') id: string, @Body() body: any) {
    const isAdmin = req.user.role === 'ADMIN';
    return this.visitsService.update(id, req.user.sub, isAdmin, body);
  }

  @Roles('ADMIN', 'SALES')
  @Delete(':id')
  delete(@Req() req: any, @Param('id') id: string) {
    const isAdmin = req.user.role === 'ADMIN';
    return this.visitsService.delete(id, req.user.sub, isAdmin);
  }

  @Roles('ADMIN', 'SALES')
  @Post(':id/attachment')
  @UseInterceptors(FileInterceptor('file'))
  addAttachment(@Req() req: any, @Param('id') id: string, @UploadedFile() file: Express.Multer.File) {
    const isAdmin = req.user.role === 'ADMIN';
    return this.visitsService.addAttachment(id, req.user.sub, isAdmin, file);
  }

  @Roles('ADMIN', 'SALES')
  @Get('attachments/:fileId/signed-url')
  getAttachmentUrl(@Param('fileId') fileId: string) {
    return this.visitsService.getAttachmentUrl(fileId);
  }
}
