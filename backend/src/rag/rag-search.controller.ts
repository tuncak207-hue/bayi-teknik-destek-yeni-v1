import { Controller, Get, Post, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard, Roles } from '../auth/guards/jwt-auth.guard';
import { RagSearchService } from './rag-search.service';
import { RagIngestionService } from './rag-ingestion.service';

/**
 * Bu endpoint Claude'a (Anthropic) HİÇ istek göndermez — sadece embedding
 * araması (Voyage AI) yaparak dokümanlardaki en alakalı ham metin
 * parçalarını döner. Test/debug amaçlıdır: gerçek uygulamada kullanıcıya
 * gösterilen cevap /ai/ask endpoint'inden (Claude ile yazılmış, Türkçe,
 * kaynaklı) gelir.
 */
@UseGuards(JwtAuthGuard)
@Controller('rag')
export class RagSearchController {
  constructor(
    private ragSearch: RagSearchService,
    private ragIngestion: RagIngestionService,
  ) {}

  @Get('raw-search')
  async rawSearch(@Query('q') q: string, @Query('brand') brand?: string, @Query('model') model?: string) {
    const results = await this.ragSearch.search(q || '', { brand, model, limit: 5 });
    return {
      query: q,
      note: 'Bu ham arama sonucudur, Claude tarafından yazılmamıştır (/ai/ask kullanmaz).',
      matches: results,
    };
  }

  /**
   * Embedding sağlayıcısı değiştirildiğinde (örn. Voyage AI'dan Ollama'ya
   * geçiş) TÜM dokümanların yeniden işlenmesi (re-embed) için kullanılır.
   * Doküman/soru sayısına göre BİRKAÇ DAKİKA sürebilir — istek beklerken
   * arka planda tamamlanır, cevap dönene kadar bağlantı açık kalır.
   */
  @Roles('ADMIN')
  @UseGuards(RolesGuard)
  @Post('reprocess-all')
  async reprocessAll(@Query('force') force?: string) {
    return this.ragIngestion.reprocessAll((done, total, title) => {
      console.log(`[Yeniden İşleme] ${done}/${total}: ${title}`);
    }, force === 'true');
  }
}
