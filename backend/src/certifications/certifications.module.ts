import { Module } from '@nestjs/common';
import { CertificationsController } from './certifications.controller';
import { CertificationsService } from './certifications.service';
import { StorageService } from '../common/storage/storage.service';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [NotificationsModule],
  controllers: [CertificationsController],
  providers: [CertificationsService, StorageService],
})
export class CertificationsModule {}
