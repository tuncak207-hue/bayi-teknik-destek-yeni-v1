import { Body, Controller, Delete, Get, Param, Patch, Post, UploadedFile, UseGuards, UseInterceptors } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard, Roles } from '../auth/guards/jwt-auth.guard';
import { SlidesService } from './slides.service';

@UseGuards(JwtAuthGuard)
@Controller('slides')
export class SlidesController {
  constructor(private slides: SlidesService) {}

  /** Mobil uygulamanın kullandığı, sadece aktif slaytları döndüren uç nokta. */
  @Get()
  listActive() {
    return this.slides.listActive();
  }

  /** Admin panelin kullandığı, aktif/pasif TÜM slaytları döndüren uç nokta. */
  @Roles('ADMIN')
  @UseGuards(RolesGuard)
  @Get('all')
  listAll() {
    return this.slides.listAll();
  }

  @Roles('ADMIN')
  @UseGuards(RolesGuard)
  @Post()
  // Kullanıcı isteği: "slayt video olarak da dönebilsin" — video
  // dosyaları görsellerden çok daha büyük olduğu için sınır 10MB'tan
  // 80MB'a çıkarıldı.
  @UseInterceptors(FileInterceptor('image', { limits: { fileSize: 80 * 1024 * 1024 } }))
  create(
    @UploadedFile() file: Express.Multer.File,
    @Body() dto: { title?: string; subtitle?: string; linkUrl?: string; order?: string },
  ) {
    return this.slides.create(file, { ...dto, order: dto.order ? Number(dto.order) : undefined });
  }

  @Roles('ADMIN')
  @UseGuards(RolesGuard)
  @Patch(':id')
  update(
    @Param('id') id: string,
    @Body() dto: { title?: string; subtitle?: string; linkUrl?: string; order?: number; isActive?: boolean },
  ) {
    return this.slides.update(id, dto);
  }

  @Roles('ADMIN')
  @UseGuards(RolesGuard)
  @Delete(':id')
  delete(@Param('id') id: string) {
    return this.slides.delete(id);
  }
}
