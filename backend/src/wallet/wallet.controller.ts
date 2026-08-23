import { Controller, Get, Post, Patch, Delete, Param, Body, UseGuards, UseInterceptors, UploadedFile, Req } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { WalletService } from './wallet.service';

@UseGuards(JwtAuthGuard)
@Controller('wallet')
export class WalletController {
  constructor(private walletService: WalletService) {}

  @Get()
  list(@Req() req: any) {
    return this.walletService.list(req.user.sub);
  }

  @Post()
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: 20 * 1024 * 1024 } }))
  create(@Req() req: any, @Body() body: { name: string; category: string }, @UploadedFile() file: Express.Multer.File) {
    return this.walletService.create(req.user.sub, body.name, body.category, file);
  }

  @Patch(':id')
  update(@Req() req: any, @Param('id') id: string, @Body() body: { name?: string; category?: string }) {
    return this.walletService.update(id, req.user.sub, body.name, body.category);
  }

  @Get(':id/url')
  getSignedUrl(@Req() req: any, @Param('id') id: string) {
    return this.walletService.getSignedUrl(id, req.user.sub);
  }

  @Delete(':id')
  remove(@Req() req: any, @Param('id') id: string) {
    return this.walletService.remove(id, req.user.sub);
  }
}
