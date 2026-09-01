import { Module } from '@nestjs/common';
import { SlidesController } from './slides.controller';
import { SlidesService } from './slides.service';
import { StorageService } from '../common/storage/storage.service';
import { ChatGatewayModule } from '../chat/gateway/chat-gateway.module';

@Module({
  imports: [ChatGatewayModule],
  controllers: [SlidesController],
  providers: [SlidesService, StorageService],
})
export class SlidesModule {}
