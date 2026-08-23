import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { ChatGateway } from './chat.gateway';
import { PrismaModule } from '../../common/prisma/prisma.module';

/**
 * ChatGateway'i ayrı bir modülde tutuyoruz — hem ChatModule hem de
 * NotificationsModule bunu kullanmak istiyor (genel bildirimleri anlık
 * yayınlamak için), ChatModule zaten NotificationsModule'ü içe aktardığı
 * için NotificationsModule'ün doğrudan ChatModule'ü içe aktarması
 * döngüsel bağımlılık (circular dependency) yaratırdı.
 */
@Module({
  imports: [JwtModule.register({ secret: process.env.JWT_SECRET }), PrismaModule],
  providers: [ChatGateway],
  exports: [ChatGateway],
})
export class ChatGatewayModule {}
