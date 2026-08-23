import { Module } from '@nestjs/common';
import { WalletController } from './wallet.controller';
import { WalletService } from './wallet.service';
import { StorageService } from '../common/storage/storage.service';

@Module({
  controllers: [WalletController],
  providers: [WalletService, StorageService],
})
export class WalletModule {}
