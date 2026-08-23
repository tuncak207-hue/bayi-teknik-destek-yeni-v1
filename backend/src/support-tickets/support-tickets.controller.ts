import { Controller, Get, Post, Patch, Delete, Param, Body, Query, UseGuards, UseInterceptors, UploadedFile, Req } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard, Roles } from '../auth/guards/jwt-auth.guard';
import { SupportTicketsService } from './support-tickets.service';

@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('support-tickets')
export class SupportTicketsController {
  constructor(private ticketsService: SupportTicketsService) {}

  // ÖNEMLİ: Sabit (literal) rotalar ('settings/sla', 'measurement-types'
  // gibi) TÜM ':id' gibi dinamik rotalardan ÖNCE tanımlanmalı — aksi
  // halde NestJS bu kelimeleri bir kayıt ID'si gibi yorumlayıp yanlış
  // metoda giderdi.

  @Roles('ADMIN')
  @Get('settings/sla')
  getSlaSettings() {
    return this.ticketsService.getSlaSettings();
  }

  @Roles('ADMIN')
  @Patch('settings/sla/:priority')
  updateSlaSetting(
    @Param('priority') priority: string,
    @Body() body: { responseMinutes: number; resolutionMinutes: number },
  ) {
    return this.ticketsService.updateSlaSetting(priority, body.responseMinutes, body.resolutionMinutes);
  }

  @Roles('ADMIN')
  @Post('measurement-types')
  createMeasurementType(@Body() body: { name: string; unit: string; minValue?: number; maxValue?: number }) {
    return this.ticketsService.createMeasurementType(body.name, body.unit, body.minValue, body.maxValue);
  }

  @Get('measurement-types')
  listMeasurementTypes() {
    return this.ticketsService.listMeasurementTypes();
  }

  @Get('measurements/by-serial/:serialNumber')
  getMeasurementHistory(@Param('serialNumber') serialNumber: string) {
    return this.ticketsService.getMeasurementHistoryBySerial(serialNumber);
  }

  @Roles('ADMIN')
  @Get('spare-part-requests')
  listAllSparePartRequests() {
    return this.ticketsService.listAllSparePartRequests();
  }

  @Roles('ADMIN')
  @Patch('spare-part-requests/:id/status')
  updateSparePartStatus(@Param('id') id: string, @Body() body: { status: string }) {
    return this.ticketsService.updateSparePartStatus(id, body.status);
  }

  @Roles('ADMIN')
  @Get('reports/cost')
  getCostReport(@Query('dealerId') dealerId?: string, @Query('productName') productName?: string, @Query('from') from?: string, @Query('to') to?: string) {
    return this.ticketsService.getCostReport({ dealerId, productName, from, to });
  }

  @Roles('ADMIN')
  @Get('reports/product-health')
  listProductHealthScores() {
    return this.ticketsService.listProductHealthScores();
  }

  @Roles('ADMIN')
  @Get('reports/product-health/:serialNumber')
  getProductHealthScore(@Param('serialNumber') serialNumber: string) {
    return this.ticketsService.getProductHealthScore(serialNumber);
  }

  @Roles('ADMIN')
  @Get('reports/version-analysis/:productName')
  getVersionAnalysis(@Param('productName') productName: string) {
    return this.ticketsService.getVersionAnalysis(productName);
  }

  @Roles('ADMIN')
  @Get('reports/rnd-feedback')
  getRndFeedbackAlerts() {
    return this.ticketsService.getRndFeedbackAlerts();
  }

  @Roles('ADMIN')
  @Get('reports/heat-map')
  getHeatMapData() {
    return this.ticketsService.getHeatMapData();
  }

  @Roles('ADMIN')
  @Get('reports/anomalies')
  getAnomalies() {
    return this.ticketsService.computeAnomalies();
  }

  @Roles('ADMIN')
  @Get('reports/spare-part-forecast')
  getSparePartForecast() {
    return this.ticketsService.getSparePartForecast();
  }

  @Roles('ADMIN')
  @Get('reports/competency')
  getCompetencyScores() {
    return this.ticketsService.getCompetencyScores();
  }

  @Roles('ADMIN')
  @Get('reports/seven-day-forecast')
  getSevenDayForecast() {
    return this.ticketsService.getSevenDayForecast();
  }

  @Post()
  create(
    @Req() req: any,
    @Body()
    body: {
      productName?: string;
      productModel?: string;
      serialNumber?: string;
      location?: string;
      description: string;
      isEmergency?: boolean;
    },
  ) {
    return this.ticketsService.create(req.user.sub, body);
  }

  @Post(':id/attachment')
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: 50 * 1024 * 1024 } }))
  attachFile(@Req() req: any, @Param('id') id: string, @UploadedFile() file: Express.Multer.File) {
    return this.ticketsService.attachFile(id, req.user.sub, file);
  }

  @Get(':id/attachments')
  getAttachments(@Req() req: any, @Param('id') id: string) {
    return this.ticketsService.getSignedAttachmentUrls(id, req.user.sub);
  }

  @Post(':id/photos/:type')
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: 20 * 1024 * 1024 } }))
  addPhoto(
    @Req() req: any,
    @Param('id') id: string,
    @Param('type') type: 'BEFORE' | 'AFTER',
    @UploadedFile() file: Express.Multer.File,
  ) {
    return this.ticketsService.addPhoto(id, req.user.sub, type, file);
  }

  @Get(':id/photos')
  getPhotoComparison(@Param('id') id: string) {
    return this.ticketsService.getPhotoComparison(id);
  }

  @Roles('ADMIN', 'ENGINEER')
  @Post(':id/measurements')
  addMeasurement(@Param('id') id: string, @Body() body: { measurementTypeId: string; value: number }) {
    return this.ticketsService.addMeasurement(id, body.measurementTypeId, body.value);
  }

  @Get(':id/measurements')
  getMeasurements(@Param('id') id: string) {
    return this.ticketsService.getMeasurementsForTicket(id);
  }

  @Post(':id/spare-part-requests')
  createSparePartRequest(
    @Req() req: any,
    @Param('id') id: string,
    @Body() body: { partCode?: string; partName: string; quantity?: number },
  ) {
    return this.ticketsService.createSparePartRequest(id, req.user.sub, body.partCode, body.partName, body.quantity ?? 1);
  }

  @Get(':id/spare-part-requests')
  listSparePartRequestsForTicket(@Param('id') id: string) {
    return this.ticketsService.listSparePartRequestsForTicket(id);
  }

  @Roles('ADMIN', 'ENGINEER')
  @Post(':id/costs')
  addCost(@Param('id') id: string, @Body() body: { category: string; description?: string; amount: number }) {
    return this.ticketsService.addCost(id, body.category, body.description, body.amount);
  }

  @Get(':id/costs')
  getCosts(@Param('id') id: string) {
    return this.ticketsService.getCostsForTicket(id);
  }

  @Get()
  list(@Req() req: any, @Query('status') status?: string) {
    if (req.user.role === 'ADMIN' || req.user.role === 'ENGINEER') {
      return this.ticketsService.listAll(status);
    }
    return this.ticketsService.listForDealer(req.user.sub);
  }

  @Get(':id')
  get(@Req() req: any, @Param('id') id: string) {
    const isStaff = req.user.role === 'ADMIN' || req.user.role === 'ENGINEER';
    return this.ticketsService.get(id, req.user.sub, !isStaff);
  }

  @Roles('ADMIN')
  @Patch(':id/assign')
  assignEngineer(@Param('id') id: string, @Body() body: { engineerId: string }) {
    return this.ticketsService.assignEngineer(id, body.engineerId);
  }

  @Roles('ADMIN', 'ENGINEER')
  @Patch(':id/status')
  updateStatus(@Param('id') id: string, @Body() body: { status: string }) {
    return this.ticketsService.updateStatus(id, body.status);
  }

  @Patch(':id')
  updateTicket(
    @Req() req: any,
    @Param('id') id: string,
    @Body() body: { productName?: string; productModel?: string; serialNumber?: string; location?: string; description?: string },
  ) {
    const isStaff = req.user.role === 'ADMIN' || req.user.role === 'ENGINEER';
    return this.ticketsService.updateTicket(id, req.user.sub, isStaff, body);
  }

  @Delete(':id')
  deleteTicket(@Req() req: any, @Param('id') id: string) {
    const isStaff = req.user.role === 'ADMIN' || req.user.role === 'ENGINEER';
    return this.ticketsService.deleteTicket(id, req.user.sub, isStaff);
  }
}
