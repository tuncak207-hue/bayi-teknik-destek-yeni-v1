import { Controller, Post, Get, Patch, Body, Param, Query, UseGuards, Req, UseInterceptors, UploadedFile, ForbiddenException, BadRequestException } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { FileInterceptor } from '@nestjs/platform-express';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard, Roles } from '../auth/guards/jwt-auth.guard';
import { AiService } from './ai.service';
import { TechnicalMemoryService } from './technical-memory.service';
import { AskAiDto } from './dto/ask-ai.dto';
import { ConversationsService } from '../chat/conversations.service';
import { MessagesService } from '../chat/messages.service';
import { ChatGateway } from '../chat/gateway/chat.gateway';
import { PrismaService } from '../common/prisma/prisma.service';
import { AuthenticatedRequest } from '../common/types/authenticated-request';

@UseGuards(JwtAuthGuard)
@Controller('ai')
export class AiController {
  constructor(
    private aiService: AiService,
    private technicalMemory: TechnicalMemoryService,
    private conversations: ConversationsService,
    private messages: MessagesService,
    private gateway: ChatGateway,
    private prisma: PrismaService,
  ) {}

  /**
   * Kullanıcı isteği: "yeni sohbet dediğimde ayrı bir kart açmalı" —
   * mevcut sohbeti aramadan, her zaman TAMAMEN YENİ, ayrı bir AI
   * konuşması oluşturur. Eski konuşma değişmeden, kendi kaydında kalır.
   */
  @Post('conversations/new')
  async createNewConversation(@Req() req: AuthenticatedRequest) {
    return this.conversations.createNewAiConversation(req.user.sub);
  }

  @Post('ask')
  async ask(@Req() req: AuthenticatedRequest, @Body() dto: AskAiDto) {
    const conversationId =
      dto.conversationId ?? (await this.conversations.createAiConversation(req.user.sub)).id;

    // Kullanıcı isteği: takip sorusu tespiti için, YENİ soruyu kaydetmeden
    // ÖNCE mevcut son soru-cevap çiftini çekiyoruz.
    const { previousQuestion, previousAnswer } = await this.getPreviousExchange(conversationId);

    await this.messages.sendUserMessage({
      conversationId,
      senderId: req.user.sub,
      content: dto.question,
    });

    const answer = await this.aiService.answerTechnicalQuestion(dto.question, {
      brand: dto.brand,
      model: dto.model,
      previousQuestion,
      previousAnswer,
    });

    const aiMessage = await this.messages.saveAiAnswer(conversationId, answer);
    this.gateway.emitNewMessage(conversationId, aiMessage);

    // Kullanıcı isteği: "doğrulama sürekli kalmalı" — memoryId artık
    // Message modelinde kalıcı olarak saklanıyor (technicalMemoryId).
    // Mobil tarafın ChatMessage.fromJson'ı hep aynı şekilde okuyabilsin
    // diye memoryId'yi mesaj nesnesinin İÇİNE de ekliyoruz (yeni
    // oluşturulan bir cevap olduğu için henüz doğrulanmamış).
    const responseMessage = { ...aiMessage, memoryId: answer.memoryId, memoryIsVerified: false };

    return { conversationId, message: responseMessage, fromMemory: answer.fromMemory, memoryId: answer.memoryId };
  }

  /** Bu konuşmadaki en son kullanıcı sorusu + AI cevabını bulur (varsa). */
  private async getPreviousExchange(
    conversationId: string,
  ): Promise<{ previousQuestion?: string; previousAnswer?: string }> {
    const lastTwo = await this.prisma.message.findMany({
      where: { conversationId },
      orderBy: { createdAt: 'desc' },
      take: 2,
    });
    const lastAi = lastTwo.find((m) => m.senderType === 'AI');
    const lastUser = lastTwo.find((m) => m.senderType === 'USER');
    if (!lastAi || !lastUser) return {};
    return { previousQuestion: lastUser.content, previousAnswer: lastAi.content };
  }

  @Throttle({ default: { limit: 20, ttl: 60_000 } })
  @Post('ask-with-image')
  @UseInterceptors(
    FileInterceptor('image', {
      limits: { fileSize: 10 * 1024 * 1024 },
      fileFilter: (_req, file, callback) => {
        const allowed = ['image/jpeg', 'image/png', 'image/webp'];
        callback(null, allowed.includes(file.mimetype));
      },
    }),
  )
  async askWithImage(
    @Req() req: AuthenticatedRequest,
    @Body() dto: AskAiDto,
    @UploadedFile() image: Express.Multer.File,
  ) {
    if (!image?.buffer?.length) {
      throw new BadRequestException('Geçerli bir görsel dosyası yükleyin.');
    }
    const conversationId =
      dto.conversationId ?? (await this.conversations.createAiConversation(req.user.sub)).id;

    const { previousQuestion, previousAnswer } = await this.getPreviousExchange(conversationId);

    await this.messages.sendUserMessage({
      conversationId,
      senderId: req.user.sub,
      content: dto.question || 'Fotoğraf gönderildi.',
    });

    const answer = await this.aiService.answerTechnicalQuestion(dto.question, {
      brand: dto.brand,
      model: dto.model,
      imageBase64: image.buffer.toString('base64'),
      imageMediaType: image.mimetype,
      previousQuestion,
      previousAnswer,
    });

    const aiMessage = await this.messages.saveAiAnswer(conversationId, answer);
    this.gateway.emitNewMessage(conversationId, aiMessage);

    const responseMessage = { ...aiMessage, memoryId: answer.memoryId, memoryIsVerified: false };

    return { conversationId, message: responseMessage, fromMemory: answer.fromMemory, memoryId: answer.memoryId };
  }

  // ============================================================
  // Admin panel — "AI Teknik Hafıza" yönetimi
  // ============================================================

  @Roles('ADMIN', 'ENGINEER')
  @UseGuards(RolesGuard)
  @Get('technical-memory')
  listMemory(@Query('productName') productName?: string, @Query('needsReverification') needsReverification?: string) {
    return this.technicalMemory.list({
      productName,
      needsReverification: needsReverification === undefined ? undefined : needsReverification === 'true',
    });
  }

  // Kullanıcı isteği: "herkes (bütün bayiler) doğrulayabilsin" — bu
  // endpoint artık ADMIN/ENGINEER ile sınırlı değil, giriş yapmış her
  // kullanıcı (JwtAuthGuard zaten sınıf seviyesinde uygulanıyor) bir
  // AI cevabını "doğru" olarak işaretleyebilir.
  @Patch('technical-memory/:id/verify')
  verifyMemory(@Req() req: AuthenticatedRequest, @Param('id') id: string) {
    return this.technicalMemory.verify(id, req.user.sub);
  }

  @Roles('ADMIN', 'ENGINEER')
  @UseGuards(RolesGuard)
  @Patch('technical-memory/:id')
  updateMemory(@Param('id') id: string, @Body() body: { answerMarkdown: string }) {
    return this.technicalMemory.updateAnswer(id, body.answerMarkdown);
  }

  @Roles('ADMIN', 'ENGINEER')
  @UseGuards(RolesGuard)
  @Patch('technical-memory/:id/active')
  setMemoryActive(@Param('id') id: string, @Body() body: { isActive: boolean }) {
    return this.technicalMemory.setActive(id, body.isActive);
  }

  // Kullanıcı isteği: "Çok Dilli Anlık Çeviri (Sohbet İçi)" — ayrı bir
  // çeviri servisi/API anahtarı eklemek yerine, zaten kullandığımız AI
  // sağlayıcıyı ("bu metni X diline çevir" promptuyla) kullanıyoruz.
  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  @Post('translate')
  translate(@Body() body: { text: string; targetLanguage: string }) {
    return this.aiService.translate(body.text, body.targetLanguage);
  }
}
