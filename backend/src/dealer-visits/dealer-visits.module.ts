import { Module } from '@nestjs/common';
import { DealerVisitsController } from './dealer-visits.controller';
import { DealerVisitsService } from './dealer-visits.service';
import { PrismaModule } from '../common/prisma/prisma.module';
import { StorageService } from '../common/storage/storage.service';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [PrismaModule, NotificationsModule],
  controllers: [DealerVisitsController],
  providers: [DealerVisitsService, StorageService],
})
export class DealerVisitsModule {}
