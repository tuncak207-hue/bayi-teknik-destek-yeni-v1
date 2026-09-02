import { Controller, Get, Post, Patch, Delete, Param, Body, Req, UseGuards, UseInterceptors, UploadedFile } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard, Roles } from '../auth/guards/jwt-auth.guard';
import { TrainingService } from './training.service';

@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('training')
export class TrainingController {
  constructor(private trainingService: TrainingService) {}

  @Get()
  list(@Req() req: any) {
    return this.trainingService.list(req.user.sub);
  }

  @Get(':id/url')
  getFileUrl(@Param('id') id: string) {
    return this.trainingService.getFileUrl(id);
  }

  // Kullanıcı isteği: "izleyen kişi tamamladım desin" — bu butona basınca
  // çağrılır.
  @Post(':id/complete')
  markCompleted(@Param('id') id: string, @Req() req: any) {
    return this.trainingService.markCompleted(id, req.user.sub);
  }

  // Kullanıcı isteği: "admin panelinde kim izledi kim izlemedi bilelim"
  @Roles('ADMIN')
  @Get(':id/completions')
  getCompletions(@Param('id') id: string) {
    return this.trainingService.getCompletionsForAdmin(id);
  }

  @Roles('ADMIN')
  @Post()
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: 200 * 1024 * 1024 } }))
  create(
    @Body() body: { title: string; description?: string; type: 'VIDEO' | 'DOCUMENT'; category?: string; url?: string; requiresCompletion?: string; deadlineHours?: string },
    @UploadedFile() file?: Express.Multer.File,
  ) {
    const parsed = {
      ...body,
      requiresCompletion: body.requiresCompletion === 'true' || (body.requiresCompletion as any) === true,
      deadlineHours: body.deadlineHours ? Number(body.deadlineHours) : undefined,
    };
    if (file) {
      return this.trainingService.createWithFile(parsed, file);
    }
    return this.trainingService.createWithUrl(parsed as any);
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
