import { Controller, Get, Post, Patch, Delete, Param, Body, Req, UseGuards, UseInterceptors, UploadedFile } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard, Roles } from '../auth/guards/jwt-auth.guard';
import { TrainingService } from './training.service';
import { Throttle } from '@nestjs/throttler';
import { AuthenticatedRequest } from '../common/types/authenticated-request';

@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('training')
export class TrainingController {
  constructor(private trainingService: TrainingService) {}

  @Get()
  list(@Req() req: AuthenticatedRequest) {
    return this.trainingService.list(req.user.sub);
  }

  @Get(':id/url')
  getFileUrl(@Param('id') id: string) {
    return this.trainingService.getFileUrl(id);
  }

  // Kullanıcı isteği: "izleyen kişi tamamladım desin" — bu butona basınca
  // çağrılır.
  @Post(':id/complete')
  markCompleted(@Param('id') id: string, @Req() req: AuthenticatedRequest) {
    return this.trainingService.markCompleted(id, req.user.sub);
  }

  // Kullanıcı isteği: "AI Sınav/Sertifikasyon Motoru"
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @Get(':id/quiz')
  getQuiz(@Param('id') id: string) {
    return this.trainingService.getOrGenerateQuiz(id);
  }

  @Post(':id/quiz/submit')
  submitQuiz(@Param('id') id: string, @Req() req: AuthenticatedRequest, @Body() body: { answers: number[] }) {
    return this.trainingService.submitQuiz(id, req.user.sub, body.answers);
  }

  @Get(':id/quiz/my-best')
  getMyBestQuizAttempt(@Param('id') id: string, @Req() req: AuthenticatedRequest) {
    return this.trainingService.getMyBestQuizAttempt(id, req.user.sub);
  }

  // Kullanıcı isteği: "admin panelinde kim izledi kim izlemedi bilelim"
  @Roles('ADMIN')
  @Get(':id/completions')
  getCompletions(@Param('id') id: string) {
    return this.trainingService.getCompletionsForAdmin(id);
  }

  @Roles('ADMIN')
  @Post()
  @Throttle({ default: { limit: 20, ttl: 60_000 } })
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
