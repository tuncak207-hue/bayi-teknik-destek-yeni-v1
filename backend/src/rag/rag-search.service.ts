import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../common/prisma/prisma.service';
import { EmbeddingService } from './embedding.service';

export interface RetrievedChunk {
  chunkId: string;
  documentId: string;
  documentTitle: string;
  brand: string;
  model: string;
  version: string;
  page: number;
  content: string;
  similarity: number; // 0-1, yüksek = daha alakalı
  isDatasheet?: boolean;
}

// Kullanıcı isteği (Manus önerisi, mevcut şemaya uyarlanmış hali):
// "Datasheet-First RAG" — resmi datasheet olarak işaretli kaynaklarda bu
// eşiğin üzerinde bir eşleşme bulunursa, genel dokümanlara hiç bakılmadan
// SADECE datasheet sonucu kullanılır (daha güvenilir, resmi kaynak).
const DATASHEET_CONFIDENCE_THRESHOLD = 0.7;

@Injectable()
export class RagSearchService {
  private readonly logger = new Logger(RagSearchService.name);

  constructor(private prisma: PrismaService, private embedding: EmbeddingService) {}

  /**
   * Kullanıcı sorgusunu embed edip, pgvector cosine distance ile en alakalı
   * chunk'ları getirir. Sadece güncel (isCurrent=true) doküman versiyonları
   * aranır. brand/model verilmişse metadata ile daraltılır.
   *
   * İKİ AŞAMALI: önce SADECE datasheet işaretli kaynaklarda yüksek eşikle
   * aranır — yeterince iyi bir eşleşme varsa SADECE o kullanılır (resmi
   * kaynak, genel dokümanlarla karışmaz). Yoksa tüm dokümanlarda normal
   * aramaya devam edilir.
   */
  async search(
    query: string,
    opts: { brand?: string; model?: string; limit?: number } = {},
  ): Promise<RetrievedChunk[]> {
    const limit = opts.limit ?? 6;
    const [queryVector] = await this.embedding.embedBatch([query]);
    const vectorLiteral = `[${queryVector.join(',')}]`;

    const datasheetResults = await this.runSearch(vectorLiteral, { ...opts, limit, datasheetOnly: true });
    if (datasheetResults.length > 0 && datasheetResults[0].similarity >= DATASHEET_CONFIDENCE_THRESHOLD) {
      this.logger.log(
        `[Datasheet-First] Yüksek güvenilirlikte datasheet eşleşmesi bulundu (${datasheetResults[0].similarity.toFixed(2)}), genel dokümanlara bakılmadı.`,
      );
      return datasheetResults;
    }

    return this.runSearch(vectorLiteral, { ...opts, limit, datasheetOnly: false });
  }

  private async runSearch(
    vectorLiteral: string,
    opts: { brand?: string; model?: string; limit: number; datasheetOnly: boolean },
  ): Promise<RetrievedChunk[]> {
    const brandFilter = opts.brand ? `AND d.brand ILIKE $2` : '';
    const modelFilter = opts.model ? `AND d.model ILIKE $${opts.brand ? 3 : 2}` : '';
    const datasheetFilter = opts.datasheetOnly ? `AND d."isDatasheet" = true` : '';
    const params: any[] = [vectorLiteral];
    if (opts.brand) params.push(`%${opts.brand}%`);
    if (opts.model) params.push(`%${opts.model}%`);
    params.push(opts.limit);

    const rows: any[] = await this.prisma.$queryRawUnsafe(
      `
      SELECT
        c.id as "chunkId",
        d.id as "documentId",
        d.title as "documentTitle",
        d.brand as brand,
        d.model as model,
        dv.version as version,
        c.page as page,
        c.content as content,
        d."isDatasheet" as "isDatasheet",
        1 - (c.embedding <=> $1::vector) as similarity
      FROM document_chunks c
      JOIN document_versions dv ON dv.id = c."documentVersionId"
      JOIN documents d ON d.id = dv."documentId"
      WHERE dv."isCurrent" = true
        AND d.status = 'READY'
        ${brandFilter}
        ${modelFilter}
        ${datasheetFilter}
      ORDER BY c.embedding <=> $1::vector ASC
      LIMIT $${params.length}
      `,
      ...params,
    );

    return rows.map((r) => ({ ...r, similarity: Number(r.similarity) }));
  }
}
