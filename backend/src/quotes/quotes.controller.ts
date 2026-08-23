import { Controller, Get, Post, Put, Delete, Param, Body, UseGuards, UseInterceptors, UploadedFile, Req } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard, Roles } from '../auth/guards/jwt-auth.guard';
import { QuotesService } from './quotes.service';

@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('quotes')
export class QuotesController {
  constructor(private quotesService: QuotesService) {}

  @Get('price-list')
  listPriceItems() {
    return this.quotesService.listPriceItems();
  }

  @Roles('ADMIN')
  @Post('price-list')
  createPriceItem(@Body() body: { name: string; unit: string; unitPrice: number; category?: string; brand?: string; code?: string }) {
    return this.quotesService.createPriceItem(body.name, body.unit, body.unitPrice, body.category, body.brand, body.code);
  }

  @Roles('ADMIN')
  @Put('price-list/:id')
  updatePriceItem(@Param('id') id: string, @Body() body: { name: string; unit: string; unitPrice: number; category?: string; brand?: string; code?: string }) {
    return this.quotesService.updatePriceItem(id, body.name, body.unit, body.unitPrice, body.category, body.brand, body.code);
  }

  @Roles('ADMIN')
  @Delete('price-list/:id')
  deletePriceItem(@Param('id') id: string) {
    return this.quotesService.deletePriceItem(id);
  }

  @Roles('ADMIN')
  @Delete('price-list')
  deleteAllPriceItems() {
    return this.quotesService.deleteAllPriceItems();
  }

  /** Admin: Excel'den kopyalanan ham (Tab ile ayrılmış) metni toplu olarak fiyat listesine aktarır. */
  @Roles('ADMIN')
  @Post('price-list/bulk-import')
  bulkImportPriceList(@Body() body: { rawText: string }) {
    return this.quotesService.bulkImportPriceList(body.rawText);
  }

  @Roles('ADMIN')
  @Post('price-list-document')
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: 20 * 1024 * 1024 } }))
  uploadPriceListDocument(@UploadedFile() file: Express.Multer.File) {
    return this.quotesService.uploadPriceListDocument(file);
  }

  @Get('price-list-document')
  getPriceListDocumentUrl() {
    return this.quotesService.getPriceListDocumentUrl();
  }

  @Roles('ADMIN')
  @Get('all')
  listAll() {
    return this.quotesService.listAll();
  }

  @Roles('ADMIN')
  @Put(':id/status')
  updateStatus(@Param('id') id: string, @Body() body: { status: string }) {
    return this.quotesService.updateStatus(id, body.status);
  }

  @Post()
  create(
    @Req() req: any,
    @Body()
    body: {
      title: string;
      customerName?: string;
      customerPhone?: string;
      province?: string;
      district?: string;
      items: { priceListItemId: string; quantity: number }[];
    },
  ) {
    return this.quotesService.createQuote(req.user.sub, body);
  }

  @Get()
  list(@Req() req: any) {
    return this.quotesService.listForDealer(req.user.sub);
  }

  @Get(':id')
  get(@Req() req: any, @Param('id') id: string) {
    return this.quotesService.get(id, req.user.sub);
  }

  @Put(':id')
  update(
    @Req() req: any,
    @Param('id') id: string,
    @Body()
    body: {
      title: string;
      customerName?: string;
      customerPhone?: string;
      province?: string;
      district?: string;
      items: { priceListItemId: string; quantity: number }[];
    },
  ) {
    return this.quotesService.updateQuote(id, req.user.sub, body);
  }

  @Delete(':id')
  delete(@Req() req: any, @Param('id') id: string) {
    return this.quotesService.delete(id, req.user.sub);
  }
}
