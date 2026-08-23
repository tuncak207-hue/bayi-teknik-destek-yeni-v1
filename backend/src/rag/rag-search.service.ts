import { Injectable } from '@nestjs/common';
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
}

@Injectable()
export class RagSearchService {
  constructor(private prisma: PrismaService, private embedding: EmbeddingService) {}

  /**
   * Kullanıcı sorgusunu embed edip, pgvector cosine distance ile en alakalı
   * chunk'ları getirir. Sadece güncel (isCurrent=true) doküman versiyonları
   * aranır. brand/model verilmişse metadata ile daraltılır.
   */
  async search(
    query: string,
    opts: { brand?: string; model?: string; limit?: number } = {},
  ): Promise<RetrievedChunk[]> {
    const limit = opts.limit ?? 6;
    const [queryVector] = await this.embedding.embedBatch([query]);
    const vectorLiteral = `[${queryVector.join(',')}]`;

    const brandFilter = opts.brand ? `AND d.brand ILIKE $2` : '';
    const modelFilter = opts.model ? `AND d.model ILIKE $${opts.brand ? 3 : 2}` : '';
    const params: any[] = [vectorLiteral];
    if (opts.brand) params.push(`%${opts.brand}%`);
    if (opts.model) params.push(`%${opts.model}%`);
    params.push(limit);

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
        1 - (c.embedding <=> $1::vector) as similarity
      FROM document_chunks c
      JOIN document_versions dv ON dv.id = c."documentVersionId"
      JOIN documents d ON d.id = dv."documentId"
      WHERE dv."isCurrent" = true
        AND d.status = 'READY'
        ${brandFilter}
        ${modelFilter}
      ORDER BY c.embedding <=> $1::vector ASC
      LIMIT $${params.length}
      `,
      ...params,
    );

    return rows.map((r) => ({ ...r, similarity: Number(r.similarity) }));
  }
}
