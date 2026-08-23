import { Controller, Get, Post, Patch, Delete, Param, Body, UseGuards, Req } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { NotificationsService } from './notifications.service';

@UseGuards(JwtAuthGuard)
@Controller('notifications')
export class NotificationsController {
  constructor(private notificationsService: NotificationsService) {}

  @Get()
  list(@Req() req: any) {
    return this.notificationsService.listForUser(req.user.sub);
  }

  @Post('register-token')
  registerToken(@Req() req: any, @Body('token') token: string) {
    return this.notificationsService.registerToken(req.user.sub, token);
  }

  @Post('unregister-token')
  unregisterToken(@Req() req: any, @Body('token') token: string) {
    return this.notificationsService.unregisterToken(req.user.sub, token);
  }

  @Patch('read-all')
  markAllRead(@Req() req: any) {
    return this.notificationsService.markAllRead(req.user.sub);
  }

  @Get('unread-count')
  unreadCount(@Req() req: any) {
    return this.notificationsService.unreadCount(req.user.sub);
  }

  @Get('unread-message-count')
  unreadMessageCount(@Req() req: any) {
    return this.notificationsService.unreadMessageCount(req.user.sub);
  }

  @Get('unread-counts-by-category')
  unreadCountsByCategory(@Req() req: any) {
    return this.notificationsService.unreadCountsByCategory(req.user.sub);
  }

  @Get('unread-conversation-ids')
  unreadConversationIds(@Req() req: any) {
    return this.notificationsService.unreadConversationIds(req.user.sub);
  }

  @Post('mark-conversation-read/:conversationId')
  markConversationRead(@Req() req: any, @Param('conversationId') conversationId: string) {
    return this.notificationsService.markConversationRead(req.user.sub, conversationId);
  }

  @Post('mark-type-read/:type')
  markAllOfTypeRead(@Req() req: any, @Param('type') type: string) {
    return this.notificationsService.markAllOfTypeRead(req.user.sub, type as any);
  }

  @Post('mark-category-read/:category')
  markCategoryRead(@Req() req: any, @Param('category') category: string) {
    return this.notificationsService.markCategoryRead(req.user.sub, category);
  }

  @Patch(':id/read')
  markRead(@Req() req: any, @Param('id') id: string) {
    return this.notificationsService.markRead(req.user.sub, id);
  }

  // "clear-all" literal rotası, ':id' parametre rotasından ÖNCE
  // tanımlanmalı — aksi halde "clear-all" bir bildirim ID'si gibi
  // yorumlanıp yanlış metoda gider.
  @Delete('clear-all')
  removeAll(@Req() req: any) {
    return this.notificationsService.removeAll(req.user.sub);
  }

  @Delete(':id')
  remove(@Req() req: any, @Param('id') id: string) {
    return this.notificationsService.remove(req.user.sub, id);
  }
}
