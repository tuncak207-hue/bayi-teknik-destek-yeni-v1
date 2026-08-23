import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { ChatController } from './chat.controller';
import { ConversationsService } from './conversations.service';
import { MessagesService } from './messages.service';
import { ChatGatewayModule } from './gateway/chat-gateway.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { StorageService } from '../common/storage/storage.service';

@Module({
  imports: [NotificationsModule, ChatGatewayModule, JwtModule.register({ secret: process.env.JWT_SECRET })],
  controllers: [ChatController],
  providers: [ConversationsService, MessagesService, StorageService],
  exports: [ConversationsService, MessagesService, ChatGatewayModule],
})
export class ChatModule {}
