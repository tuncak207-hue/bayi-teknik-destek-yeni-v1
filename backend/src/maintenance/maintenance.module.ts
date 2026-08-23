import { Module } from '@nestjs/common';
import { MaintenanceController } from './maintenance.controller';
import { MaintenanceService } from './maintenance.service';
import { StorageService } from '../common/storage/storage.service';

@Module({
  controllers: [MaintenanceController],
  providers: [MaintenanceService, StorageService],
})
export class MaintenanceModule {}
