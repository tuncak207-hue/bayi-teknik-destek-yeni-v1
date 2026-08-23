import { Module } from '@nestjs/common';
import { CommissioningController } from './commissioning.controller';
import { CommissioningService } from './commissioning.service';
import { StorageService } from '../common/storage/storage.service';

@Module({
  controllers: [CommissioningController],
  providers: [CommissioningService, StorageService],
})
export class CommissioningModule {}
