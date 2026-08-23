import { Controller, Get, Post, Param, UseGuards, Req } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { FavoritesService } from './favorites.service';

@UseGuards(JwtAuthGuard)
@Controller('favorites')
export class FavoritesController {
  constructor(private favoritesService: FavoritesService) {}

  @Get()
  list(@Req() req: any) {
    return this.favoritesService.list(req.user.sub);
  }

  @Get('pinned')
  listPinned(@Req() req: any) {
    return this.favoritesService.listPinned(req.user.sub);
  }

  @Post(':id/pin')
  togglePin(@Req() req: any, @Param('id') id: string) {
    return this.favoritesService.togglePin(req.user.sub, id);
  }

  @Post('documents/:documentId')
  toggleDocument(@Req() req: any, @Param('documentId') documentId: string) {
    return this.favoritesService.toggleDocumentFavorite(req.user.sub, documentId);
  }
}
