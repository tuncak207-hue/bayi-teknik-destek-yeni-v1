import { Controller, Get, Query, UseGuards, Req } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { SearchService } from './search.service';

@UseGuards(JwtAuthGuard)
@Controller('search')
export class SearchController {
  constructor(private searchService: SearchService) {}

  @Get()
  search(@Req() req: any, @Query('q') q: string) {
    return this.searchService.search(q || '', req.user.sub);
  }

  @Get('document-content')
  searchDocumentContent(@Query('q') q: string) {
    return this.searchService.searchDocumentContent(q || '');
  }
}
