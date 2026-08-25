import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Param,
  Body,
  Query,
  UseGuards,
  Req,
  UseInterceptors,
  UploadedFile,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard, Roles } from '../auth/guards/jwt-auth.guard';
import { ConversationsService } from './conversations.service';
import { MessagesService } from './messages.service';
import { ChatGateway } from './gateway/chat.gateway';
import { StorageService } from '../common/storage/storage.service';
import { SendMessageDto, StartDirectDto } from './dto/chat.dto';

@UseGuards(JwtAuthGuard)
@Controller('chat')
export class ChatController {
  constructor(
    private conversations: ConversationsService,
    private messages: MessagesService,
    private gateway: ChatGateway,
    private storage: StorageService,
  ) {}

  @Get('conversations')
  listConversations(@Req() req: any, @Query('archived') archived?: string) {
    return this.conversations.listForUser(req.user.sub, archived === 'true');
  }

  // ---- Admin moderasyon uç noktaları ----
  // Not: Sabit ':id' rotalarıyla çakışmasın diye 'admin/...' rotaları
  // 'conversations/:id' gibi genel rotalardan ÖNCE tanımlanmalı.

  @UseGuards(RolesGuard)
  @Roles('ADMIN')
  @Get('admin/conversations')
  adminListConversations() {
    return this.messages.adminListConversations();
  }

  @UseGuards(RolesGuard)
  @Roles('ADMIN')
  @Get('admin/conversations/:id/messages')
  adminListMessages(@Param('id') id: string) {
    return this.messages.adminListMessages(id);
  }

  @UseGuards(RolesGuard)
  @Roles('ADMIN')
  @Delete('admin/conversations/:id')
  adminDeleteConversation(@Param('id') id: string) {
    return this.messages.adminDeleteConversation(id);
  }

  @UseGuards(RolesGuard)
  @Roles('ADMIN')
  @Delete('admin/messages/:id')
  adminDeleteMessage(@Param('id') id: string) {
    return this.messages.adminDeleteMessage(id);
  }

  @Post('conversations/direct')
  startDirect(@Req() req: any, @Body() dto: StartDirectDto) {
    return this.conversations.findOrCreateDirectConversation(req.user.sub, dto.otherUserId);
  }

  @Get('conversations/:id/messages')
  listMessages(@Req() req: any, @Param('id') id: string, @Query('cursor') cursor?: string) {
    return this.messages.listMessages(id, req.user.sub, cursor);
  }

  @Get('conversations/:id/messages/search')
  searchMessages(@Req() req: any, @Param('id') id: string, @Query('q') q: string) {
    return this.messages.searchMessages(id, req.user.sub, q);
  }

  @Post('messages/:id/react')
  toggleReaction(@Req() req: any, @Param('id') id: string, @Body('emoji') emoji: string) {
    return this.messages.toggleReaction(req.user.sub, id, emoji);
  }

  @Post('conversations/:id/messages')
  async sendMessage(@Req() req: any, @Param('id') id: string, @Body() dto: SendMessageDto) {
    const message = await this.messages.sendUserMessage({
      conversationId: id,
      senderId: req.user.sub,
      content: dto.content,
      replyToId: dto.replyToId,
    });
    this.gateway.emitNewMessage(id, message);
    return message;
  }

  @Post('conversations/:id/attachments')
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: 10 * 1024 * 1024 } })) // 10 MB sınırı
  async sendAttachment(
    @Req() req: any,
    @Param('id') id: string,
    @UploadedFile() file: Express.Multer.File,
  ) {
    const key = await this.storage.upload(file.buffer, file.originalname, file.mimetype, 'chat');
    const attachmentType = file.mimetype.startsWith('image/')
      ? 'image'
      : file.mimetype === 'application/pdf'
        ? 'pdf'
        : 'file';
    const message = await this.messages.sendUserMessage({
      conversationId: id,
      senderId: req.user.sub,
      content: file.originalname,
      attachmentUrl: key,
      attachmentType,
    });
    this.gateway.emitNewMessage(id, message);
    return message;
  }

  @Post('messages/:id/favorite')
  toggleFavorite(@Req() req: any, @Param('id') id: string) {
    return this.messages.toggleFavorite(req.user.sub, id);
  }

  /** Kullanıcı kendi mesajını siler. */
  @Delete('messages/:id')
  deleteOwnMessage(@Req() req: any, @Param('id') id: string) {
    return this.messages.deleteOwnMessage(req.user.sub, id);
  }

  /** Karşı tarafın gönderdiği mesajı, sadece bu kullanıcının görünümünden gizler. */
  @Post('messages/:id/hide-for-me')
  hideMessageForMe(@Req() req: any, @Param('id') id: string) {
    return this.messages.hideMessageForMe(req.user.sub, id);
  }

  @Patch('messages/:id')
  editOwnMessage(@Req() req: any, @Param('id') id: string, @Body('content') content: string) {
    return this.messages.editOwnMessage(req.user.sub, id, content);
  }

  /** Bayiler sekmesinin gösterdiği ortak "Genel Sohbet" konuşması. */
  @Get('general-conversation')
  getGeneralConversation(@Req() req: any) {
    return this.conversations.getOrJoinGeneralConversation(req.user.sub);
  }

  /** WhatsApp tarzı "sohbeti sil" — sadece bu kullanıcının listesinden gizler, geçmişi yok etmez. */
  @Delete('conversations/:id')
  hideConversation(@Req() req: any, @Param('id') id: string) {
    return this.conversations.hideForUser(id, req.user.sub);
  }

  /** Kullanıcı isteği: "mesajlara arşivleme ekle". */
  @Post('conversations/:id/archive')
  archiveConversation(@Req() req: any, @Param('id') id: string) {
    return this.conversations.archiveForUser(id, req.user.sub);
  }

  @Post('conversations/:id/unarchive')
  unarchiveConversation(@Req() req: any, @Param('id') id: string) {
    return this.conversations.unarchiveForUser(id, req.user.sub);
  }

  /** "Gönderildi/okundu" tikleri için katılımcıların okuma zamanlarını döner. */
  @Get('conversations/:id/participants')
  getParticipants(@Param('id') id: string) {
    return this.conversations.getParticipants(id);
  }

  @Post('messages/:id/feedback')
  setFeedback(@Req() req: any, @Param('id') id: string, @Body('feedback') feedback: 'UP' | 'DOWN' | null) {
    return this.messages.setFeedback(req.user.sub, id, feedback);
  }

  @Get('attachments/signed-url')
  getAttachmentUrl(@Req() req: any, @Query('key') key: string) {
    return this.messages.getAttachmentSignedUrl(req.user.sub, key);
  }
}
