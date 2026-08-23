import {
  WebSocketGateway,
  WebSocketServer,
  SubscribeMessage,
  MessageBody,
  ConnectedSocket,
  OnGatewayConnection,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { JwtService } from '@nestjs/jwt';
import { Logger } from '@nestjs/common';
import { PrismaService } from '../../common/prisma/prisma.service';

@WebSocketGateway({ cors: true, namespace: '/chat' })
export class ChatGateway implements OnGatewayConnection {
  @WebSocketServer() server: Server;
  private readonly logger = new Logger(ChatGateway.name);

  constructor(private jwt: JwtService, private prisma: PrismaService) {}

  async handleConnection(socket: Socket) {
    try {
      const token = socket.handshake.auth?.token as string;
      const payload = this.jwt.verify(token, { secret: process.env.JWT_SECRET });
      socket.data.userId = payload.sub;

      // Kullanıcıyı kendi kişisel odasına da katıyoruz — Mesajlar dışındaki
      // TÜM bildirimleri (randevu, eğitim içeriği, sertifika uyarısı vb.)
      // buradan anlık olarak yayınlayabilmek için. Önceden sadece sohbet
      // odalarına katılıyordu, bu yüzden bu tür bildirimler push
      // (Firebase) yapılandırılmadıysa hiç anlık ulaşmıyordu.
      socket.join(`user:${payload.sub}`);

      const participations = await this.prisma.conversationParticipant.findMany({
        where: { userId: payload.sub },
        select: { conversationId: true },
      });
      participations.forEach((p) => socket.join(p.conversationId));
    } catch (e) {
      this.logger.warn('Yetkisiz socket bağlantısı reddedildi.');
      socket.disconnect();
    }
  }

  @SubscribeMessage('join')
  onJoin(@MessageBody() conversationId: string, @ConnectedSocket() socket: Socket) {
    socket.join(conversationId);
  }

  @SubscribeMessage('leave')
  onLeave(@MessageBody() conversationId: string, @ConnectedSocket() socket: Socket) {
    socket.leave(conversationId);
  }

  @SubscribeMessage('typing')
  onTyping(
    @MessageBody() data: { conversationId: string },
    @ConnectedSocket() socket: Socket,
  ) {
    socket.to(data.conversationId).emit('typing', { userId: socket.data.userId });
  }

  /** Diğer servisler (MessagesService, AiService) yeni mesajları buradan yayınlar. */
  emitNewMessage(conversationId: string, message: unknown) {
    this.server.to(conversationId).emit('message:new', message);
  }

  emitAiStreamChunk(conversationId: string, chunk: string) {
    this.server.to(conversationId).emit('ai:stream', chunk);
  }

  /**
   * Genel bildirim yayını — randevu, eğitim içeriği, sertifika uyarısı gibi
   * TÜM bildirim türleri için. NotificationsService.notifyUser() her
   * çağrıldığında bunu da tetikler, böylece uygulama açıkken (Firebase push
   * yapılandırılmış olsun ya da olmasın) her zaman anlık ulaşır.
   */
  emitNotification(userId: string, notification: unknown) {
    this.server.to(`user:${userId}`).emit('notification:new', notification);
  }
}
