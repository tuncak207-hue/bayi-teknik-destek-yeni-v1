import { Module } from '@nestjs/common';
import { QuotesController } from './quotes.controller';
import { QuotesService } from './quotes.service';
import { StorageService } from '../common/storage/storage.service';

@Module({
  controllers: [QuotesController],
  providers: [QuotesService, StorageService],
})
export class QuotesModule {}
