import { Module } from '@nestjs/common';
import { TrainingController } from './training.controller';
import { TrainingService } from './training.service';
import { StorageService } from '../common/storage/storage.service';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [NotificationsModule],
  controllers: [TrainingController],
  providers: [TrainingService, StorageService],
})
export class TrainingModule {}
