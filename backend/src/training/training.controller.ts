import { Controller, Get, Post, Patch, Delete, Param, Body, UseGuards, UseInterceptors, UploadedFile } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard, Roles } from '../auth/guards/jwt-auth.guard';
import { TrainingService } from './training.service';

@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('training')
export class TrainingController {
  constructor(private trainingService: TrainingService) {}

  @Get()
  list() {
    return this.trainingService.list();
  }

  @Get(':id/url')
  getFileUrl(@Param('id') id: string) {
    return this.trainingService.getFileUrl(id);
  }

  @Roles('ADMIN')
  @Post()
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: 200 * 1024 * 1024 } }))
  create(
    @Body() body: { title: string; description?: string; type: 'VIDEO' | 'DOCUMENT'; category?: string; url?: string },
    @UploadedFile() file?: Express.Multer.File,
  ) {
    if (file) {
      return this.trainingService.createWithFile(body, file);
    }
    return this.trainingService.createWithUrl(body as any);
  }

  @Roles('ADMIN')
  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.trainingService.remove(id);
  }

  @Roles('ADMIN')
  @Patch(':id')
  update(@Param('id') id: string, @Body() body: Partial<{ title: string; description: string; category: string }>) {
    return this.trainingService.update(id, body);
  }
}
