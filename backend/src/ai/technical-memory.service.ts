import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../common/prisma/prisma.service';
import { EmbeddingService } from '../rag/embedding.service';

export type MemoryTier = 'VERIFIED' | 'SIMILAR' | 'NEW';

export interface MemoryMatch {
  tier: MemoryTier;
  entry?: {
    id: string;
    question: string;
    answerMarkdown: string;
    citations: any;
    productName: string | null;
    productModel: string | null;
    lastVerifiedAt: Date | null;
    usageCount: number;
  };
  similarity?: number;
}

/**
 * AI Teknik Soru Hafızası — "Teknik Hafıza Kontrol Katmanı".
 *
 * Mevcut AI akışının ÖNÜNE eklenir: yeni bir soru geldiğinde önce burada
 * anlamsal olarak benzer, güvenilir bir geçmiş cevap aranır. Bulunursa
 * (VERIFIED) doküman taraması ATLANIR. Bulunamazsa mevcut RAG akışı
 * normal şekilde çalışmaya devam eder ve sonuç buraya kaydedilir.
 */
@Injectable()
export class TechnicalMemoryService {
  private readonly logger = new Logger(TechnicalMemoryService.name);

  // Eşik değerleri: pgvector kosinüs benzerliği (1 - mesafe).
  private readonly VERIFIED_THRESHOLD = 0.9;
  private readonly SIMILAR_THRESHOLD = 0.78;

  constructor(private prisma: PrismaService, private embedding: EmbeddingService) {}

  /**
   * Adım 1-5 (kullanıcı akışı): soru geçmişinde ara, ürün/model kontrolü
   * yap, uygun ve güvenilir bir eşleşme varsa VERIFIED döner.
   */
  async findMatch(question: string, opts: { productName?: string; productModel?: string } = {}): Promise<MemoryMatch> {
    let queryVector: number[];
    try {
      [queryVector] = await this.embedding.embedBatch([question]);
    } catch (e) {
      // Embedding servisi geçici olarak erişilemezse hafıza katmanını
      // sessizce atla — normal AI akışı (doküman taraması) devam etsin.
      this.logger.warn(`Hafıza için embedding alınamadı, katman atlanıyor: ${e}`);
      return { tier: 'NEW' };
    }
    const vectorLiteral = `[${queryVector.join(',')}]`;

    const results: any[] = await this.prisma.$queryRawUnsafe(
      `SELECT id, question, "answerMarkdown", citations, "productName", "productModel",
              "lastVerifiedAt", "needsReverification", "usageCount",
              1 - (embedding <=> $1::vector) as similarity
       FROM technical_answer_memory
       WHERE embedding IS NOT NULL AND "isActive" = true
       ORDER BY embedding <=> $1::vector ASC
       LIMIT 5`,
      vectorLiteral,
    );

    if (results.length === 0) return { tier: 'NEW' };

    const best = results[0];
    const similarity = Number(best.similarity);

    if (similarity < this.SIMILAR_THRESHOLD) return { tier: 'NEW' };

    // Ürün/model kontrolü — kullanıcı isteği: "başka bir cihaz/model için
    // oluşturulduysa doğrudan kullanılmamalı." Soru bir ürünle ilgiliyse
    // ve eşleşen kayıt FARKLI bir ürün/modele aitse, bu eşleşmeyi
    // reddedip en fazla SIMILAR (dokümanları kontrol et) diyoruz.
    const productMismatch =
      (opts.productName && best.productName && opts.productName.toLowerCase() !== best.productName.toLowerCase()) ||
      (opts.productModel && best.productModel && opts.productModel.toLowerCase() !== best.productModel.toLowerCase());

    const entry = {
      id: best.id,
      question: best.question,
      answerMarkdown: best.answerMarkdown,
      citations: best.citations,
      productName: best.productName,
      productModel: best.productModel,
      lastVerifiedAt: best.lastVerifiedAt,
      usageCount: best.usageCount,
    };

    const isVerified = !!best.lastVerifiedAt && !best.needsReverification;

    if (similarity >= this.VERIFIED_THRESHOLD && isVerified && !productMismatch) {
      return { tier: 'VERIFIED', entry, similarity };
    }

    return { tier: 'SIMILAR', entry, similarity };
  }

  /** Kullanılma sayısını artırır (VERIFIED bir eşleşme doğrudan kullanıldığında). */
  async incrementUsage(id: string) {
    await this.prisma.technicalAnswerMemory.update({ where: { id }, data: { usageCount: { increment: 1 } } });
  }

  /** Adım 7: yeni oluşturulan bir cevap hafızaya kaydedilir. */
  async save(params: {
    question: string;
    answerMarkdown: string;
    citations: any;
    productName?: string;
    productModel?: string;
    productSeries?: string;
  }) {
    try {
      const entry = await this.prisma.technicalAnswerMemory.create({
        data: {
          question: params.question,
          answerMarkdown: params.answerMarkdown,
          citations: params.citations,
          productName: params.productName,
          productModel: params.productModel,
          productSeries: params.productSeries,
        },
      });

      const [vector] = await this.embedding.embedBatch([params.question]);
      const vectorLiteral = `[${vector.join(',')}]`;
      await this.prisma.$executeRawUnsafe(
        `UPDATE technical_answer_memory SET embedding = $1::vector WHERE id = $2`,
        vectorLiteral,
        entry.id,
      );
      return entry;
    } catch (e) {
      // Hafızaya kayıt başarısız olsa bile kullanıcıya verilen cevabı
      // etkilememesi için hatayı yutuyoruz — sadece logluyoruz.
      this.logger.warn(`Teknik hafızaya kayıt başarısız: ${e}`);
      return null;
    }
  }

  // ============================================================
  // Admin panel — "AI Teknik Hafıza" yönetimi
  // ============================================================

  list(filters: { productName?: string; needsReverification?: boolean } = {}) {
    return this.prisma.technicalAnswerMemory.findMany({
      where: {
        ...(filters.productName && { productName: { contains: filters.productName, mode: 'insensitive' } }),
        ...(filters.needsReverification !== undefined && { needsReverification: filters.needsReverification }),
      },
      orderBy: { updatedAt: 'desc' },
      include: { verifiedByEngineer: { select: { firstName: true, lastName: true } } },
    });
  }

  async verify(id: string, engineerId: string) {
    return this.prisma.technicalAnswerMemory.update({
      where: { id },
      data: { verifiedByEngineerId: engineerId, lastVerifiedAt: new Date(), needsReverification: false },
    });
  }

  async updateAnswer(id: string, answerMarkdown: string) {
    // Cevap düzenlendiğinde doğrulama sıfırlanır — değiştirilmiş bir
    // cevabın otomatik "doğrulanmış" kalması güvenli değil.
    return this.prisma.technicalAnswerMemory.update({
      where: { id },
      data: { answerMarkdown, lastVerifiedAt: null, needsReverification: false },
    });
  }

  async setActive(id: string, isActive: boolean) {
    return this.prisma.technicalAnswerMemory.update({ where: { id }, data: { isActive } });
  }

  /**
   * Bir doküman güncellendiğinde/yeniden işlendiğinde, o ürüne ait
   * hafıza kayıtlarını "yeniden doğrulama gerekli" olarak işaretler.
   */
  async markNeedsReverification(brand?: string, model?: string) {
    if (!brand && !model) return;
    await this.prisma.technicalAnswerMemory.updateMany({
      where: {
        OR: [...(brand ? [{ productName: { equals: brand, mode: 'insensitive' as const } }] : []), ...(model ? [{ productModel: { equals: model, mode: 'insensitive' as const } }] : [])],
      },
      data: { needsReverification: true },
    });
  }
}
