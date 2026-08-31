import { Inject, Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../common/prisma/prisma.service';
import { TextExtractionService } from './text-extraction.service';
import { EmbeddingService } from './embedding.service';
import { StorageService } from '../common/storage/storage.service';
import { AIProvider, AI_PROVIDER } from '../ai/providers/ai-provider.interface';

const CHUNK_SIZE = 800; // karakter
const CHUNK_OVERLAP = 150;

const DIAGRAM_PROMPT = `Bu, bir yangın alarm/güvenlik kamera teknik dokümanının bir sayfasının görselidir.
Sayfada bir bağlantı şeması, kablolama diyagramı, blok diyagramı veya teknik çizim VARSA:
- Şemadaki bileşenleri, bağlantıları ve önemli etiketleri/değerleri Türkçe olarak, madde
  madde ve net şekilde açıkla (örn. "Terminal 1 (NC) - Siren + kutbuna bağlanır" gibi).
- Şemada yazan İngilizce etiketleri de Türkçe karşılığıyla birlikte belirt.
Sayfada teknik bir şema/diyagram YOKSA (sadece düz metin/tablo varsa), SADECE şu kelimeyi yaz: YOK
Cevabına başka hiçbir giriş/açıklama cümlesi ekleme, direkt açıklamayla ya da "YOK" ile başla.`;

@Injectable()
export class RagIngestionService {
  private readonly logger = new Logger(RagIngestionService.name);

  constructor(
    private prisma: PrismaService,
    private extraction: TextExtractionService,
    private embedding: EmbeddingService,
    private storage: StorageService,
    @Inject(AI_PROVIDER) private aiProvider: AIProvider,
  ) {}

  /**
   * Doküman versiyonunu işler: extract -> chunk -> embed -> pgvector'a yaz.
   * Döndürdüğü değer sayfa sayısıdır (document_versions.pageCount için).
   */
  async processDocumentVersion(
    versionId: string,
    buffer: Buffer,
    mimeType: string,
  ): Promise<number> {
    const pages = await this.extraction.extract(buffer, mimeType);

    // Kullanıcı isteği: "şemaları incelemeli ve şemayı açıklamalı" — PDF
    // sayfaları görsele render edilip, görsel destekli AI'dan şema/diyagram
    // varsa Türkçe açıklaması isteniyor. Bu açıklama, sayfanın metnine
    // eklenerek aramalarda ve cevaplarda kullanılabilir hale geliyor.
    // ÖNEMLİ: Görsel analiz başarısız olursa (örn. o an aktif model görsel
    // desteklemiyorsa) sessizce atlanır — dokümanın normal metin işlenmesi
    // bundan ETKİLENMEZ, sadece şema açıklaması eksik kalır.
    // Kullanıcı isteği: şema/diyagram analizi açık kalsın, ama daha
    // güvenilir çalışsın (aşağıda tekrar deneme ve daha uzun zaman aşımı
    // eklendi).
    // Görsel şema analizi pahalı ve sayfa başına yavaştır. Hızlı ve
    // güvenilir doküman işleme için production'da varsayılan olarak kapalıdır;
    // gerektiğinde ENABLE_DIAGRAM_ANALYSIS=true ile ayrıca açılabilir.
    if (mimeType === 'application/pdf' && process.env.ENABLE_DIAGRAM_ANALYSIS === 'true') {
      await this.appendDiagramDescriptions(buffer, pages);
    }

    type PendingChunk = { page: number; chunkIndex: number; content: string };
    const pendingChunks: PendingChunk[] = [];

    for (const page of pages) {
      const chunks = this.splitIntoChunks(page.text);
      chunks.forEach((content, idx) => {
        if (content.trim().length > 0) {
          pendingChunks.push({ page: page.page, chunkIndex: idx, content });
        }
      });
    }

    if (pendingChunks.length === 0) {
      this.logger.warn(`Versiyon ${versionId} için çıkarılabilir metin bulunamadı.`);
      return pages.length;
    }

    // Voyage tek istekte çok sayıda metni embed edebilir. Daha büyük batch,
    // uzak API çağrısı sayısını azaltır; veritabanı yazımları da kontrollü
    // paralellik ile yapılır. Böylece Render/Supabase ağ gecikmesi her chunk
    // için ayrı ayrı toplam süreye eklenmez.
    const BATCH = 64;
    const WRITE_CONCURRENCY = 8;
    for (let i = 0; i < pendingChunks.length; i += BATCH) {
      const batch = pendingChunks.slice(i, i + BATCH);
      const vectors = await this.embedding.embedBatch(batch.map((c) => c.content));

      for (let j = 0; j < batch.length; j += WRITE_CONCURRENCY) {
        const writes = batch.slice(j, j + WRITE_CONCURRENCY).map((chunk, offset) => {
          const vector = vectors[j + offset];
          const id = crypto.randomUUID();
          // pgvector kolonuna Prisma'nın native desteği olmadığı için raw SQL kullanılıyor.
          return this.prisma.$executeRawUnsafe(
            `INSERT INTO document_chunks (id, "documentVersionId", page, "chunkIndex", content, embedding, "createdAt")
             VALUES ($1, $2, $3, $4, $5, $6::vector, now())`,
            id,
            versionId,
            chunk.page,
            chunk.chunkIndex,
            chunk.content,
            `[${vector.join(',')}]`,
          );
        });
        await Promise.all(writes);
      }
    }

    this.logger.log(`Versiyon ${versionId}: ${pendingChunks.length} chunk işlendi.`);
    return pages.length;
  }

  /**
   * PDF sayfalarını görsele render edip, aktif AI sağlayıcısından şema/
   * diyagram açıklaması ister, sonucu `pages[].text`'in sonuna ekler.
   * Görsel destekli olmayan bir model kullanılıyorsa (örn. sadece metin
   * modeli) ya da render başarısız olursa, hatayı loglayıp sessizce devam
   * eder — dokümanın normal metin işlenmesini ASLA engellemez.
   */
  private async appendDiagramDescriptions(pdfBuffer: Buffer, pages: { page: number; text: string }[]) {
    let renderedPages: { page: number; base64: string }[] = [];
    try {
      const { pdf } = require('pdf-to-img');
      const document = await pdf(pdfBuffer, { scale: 2 });
      let pageNum = 0;
      for await (const pageImage of document) {
        pageNum++;
        renderedPages.push({ page: pageNum, base64: pageImage.toString('base64') });
      }
    } catch (e) {
      this.logger.warn(`PDF sayfaları görsele render edilemedi, şema açıklaması atlanıyor: ${e}`);
      return;
    }

    for (const rendered of renderedPages) {
      // Kullanıcı isteği: şema analizi güvenilirliği artırılsın — geçici
      // ağ/model hatalarında (fetch failed, zaman aşımı vb.) bir sayfa
      // hemen pes etmek yerine 2 kez daha deneniyor.
      const MAX_ATTEMPTS = 3;
      let lastError: unknown;
      let succeeded = false;

      for (let attempt = 1; attempt <= MAX_ATTEMPTS && !succeeded; attempt++) {
        try {
          const result = await this.aiProvider.complete(
            [
              {
                role: 'user',
                content: [
                  { type: 'text', text: DIAGRAM_PROMPT },
                  { type: 'image', mediaType: 'image/png', data: rendered.base64 },
                ],
              },
            ],
            { maxTokens: 500, temperature: 0.1 },
          );
          const description = result.text.trim();
          if (description && description.toUpperCase() !== 'YOK') {
            const targetPage = pages.find((p) => p.page === rendered.page);
            if (targetPage) {
              targetPage.text += `\n\n[ŞEMA/DİYAGRAM AÇIKLAMASI - Sayfa ${rendered.page}]\n${description}`;
            }
          }
          succeeded = true;
        } catch (e) {
          lastError = e;
          if (attempt < MAX_ATTEMPTS) {
            this.logger.warn(`Sayfa ${rendered.page} şema analizi denemesi ${attempt}/${MAX_ATTEMPTS} başarısız, tekrar deneniyor: ${e}`);
            await new Promise((r) => setTimeout(r, 3000));
          }
        }
      }

      if (!succeeded) {
        // Görsel desteklemeyen bir model kullanılıyor olabilir ya da
        // model gerçekten yanıt veremiyor olabilir — bu, beklenen ve
        // zararsız bir durum, sadece uyarı olarak logluyoruz.
        this.logger.warn(`Sayfa ${rendered.page} için şema açıklaması ${MAX_ATTEMPTS} denemeden sonra alınamadı: ${lastError}`);
      }
    }
  }

  private splitIntoChunks(text: string): string[] {
    const clean = text.replace(/\s+/g, ' ').trim();
    if (!clean) return [];

    const chunks: string[] = [];
    let start = 0;
    while (start < clean.length) {
      const end = Math.min(start + CHUNK_SIZE, clean.length);
      chunks.push(clean.slice(start, end));
      if (end === clean.length) break;
      start = end - CHUNK_OVERLAP;
    }
    return chunks;
  }

  /**
   * Embedding sağlayıcısı değiştirildiğinde (örn. Voyage AI'dan Ollama'ya
   * geçildiğinde) çağrılır — TÜM doküman versiyonlarının vektörlerini
   * SIFIRDAN yeniden oluşturur. Farklı embedding modelleri birbirinden
   * TAMAMEN FARKLI bir "vektör uzayında" çalışır; eski sağlayıcıyla
   * oluşturulmuş vektörler yeni sağlayıcının sorgularıyla anlamlı şekilde
   * karşılaştırılamaz. Bu yüzden sağlayıcı değişince yeniden işleme ŞART.
   */
  /**
   * Kullanıcı isteği: "her seferinde neden tüm belgeleri işlesin ki" —
   * artık varsayılan olarak SADECE eksik/başarısız olan (henüz hiç
   * chunk'ı olmayan) dokümanlar işlenir; zaten başarıyla işlenmiş
   * dokümanlar ATLANIR. Gerçekten TÜMÜNÜ sıfırdan yeniden işlemek
   * gerekiyorsa (örn. embedding sağlayıcısı değiştiğinde) `force: true`
   * geçilmeli.
   */
  async reprocessAll(onProgress?: (done: number, total: number, title: string) => void, force = false) {
    const versions = await this.prisma.documentVersion.findMany({
      include: { document: { select: { id: true, title: true, fileType: true, status: true } } },
    });

    // force=false ise, zaten en az 1 chunk'ı olan VE durumu ERROR
    // OLMAYAN versiyonları listeden çıkarıyoruz. ÖNEMLİ DÜZELTME:
    // "hata verenleri işlemiyor ama durumu hala hata" sorunu — bir
    // doküman kısmen işlenip (bazı chunk'lar oluşup) sonra hata almışsa,
    // sadece "chunk var mı" kontrolü onu yanlışlıkla "tamamlanmış"
    // sayıyordu. Artık durumu ERROR olan dokümanlar, chunk'ı olsa bile
    // HER ZAMAN yeniden işleme listesine dahil ediliyor.
    let targets = versions;
    if (!force) {
      const existingCounts = await this.prisma.documentChunk.groupBy({
        by: ['documentVersionId'],
        _count: { id: true },
      });
      const alreadyProcessed = new Set(
        existingCounts.filter((c) => c._count.id > 0).map((c) => c.documentVersionId),
      );
      targets = versions.filter((v) => v.document.status === 'ERROR' || !alreadyProcessed.has(v.id));
    }

    let done = 0;
    for (const version of targets) {
      try {
        // ÖNEMLİ DÜZELTME: "hata olanlar yine hata olarak kalıyor" —
        // gerçek sebep, bu versiyon kaydının artık veritabanında
        // GERÇEKTEN var olmaması (muhtemelen daha önce silinen mükerrer
        // bir dokümanla ilgili bir tutarsızlık). Her denemede aynı
        // "foreign key" hatasını verip asla başarılı olamıyordu. Şimdi
        // işlemeden HEMEN ÖNCE versiyonun hâlâ var olduğunu doğruluyoruz
        // — yoksa anlamsız yere tekrar tekrar denemek yerine temiz bir
        // şekilde atlayıp dokümanı "silinmiş versiyon" hatasıyla
        // işaretliyoruz.
        const stillExists = await this.prisma.documentVersion.findUnique({ where: { id: version.id } });
        if (!stillExists) {
          this.logger.warn(`Versiyon ${version.id} (${version.document.title}) artık veritabanında yok, atlanıyor.`);
          await this.prisma.document
            .update({
              where: { id: version.document.id },
              data: {
                status: 'ERROR',
                errorMessage: 'Bu dokümanın versiyon kaydı bulunamadı — dokümanı silip yeniden yüklemeniz gerekebilir.',
              },
            })
            .catch(() => {});
          done++;
          onProgress?.(done, targets.length, version.document.title);
          continue;
        }

        // ÖNEMLİ: Şema düzeyindeki "onDelete: Cascade" ayarı beklenildiği
        // gibi devreye girmedi (sebebi netleşmedi) — bu yüzden ilgili
        // eski alıntı (MessageCitation) kayıtlarını, chunk'ları silmeden
        // ÖNCE, kod tarafında açıkça temizliyoruz. Bu, şemadan bağımsız
        // olarak kesin çalışır.
        await this.prisma.messageCitation.deleteMany({
          where: { documentChunk: { documentVersionId: version.id } },
        });
        // Eski chunk'ları (ve dolayısıyla eski embedding'leri) temizle.
        await this.prisma.documentChunk.deleteMany({ where: { documentVersionId: version.id } });
        const buffer = await this.storage.download(version.fileUrl);
        await this.processDocumentVersion(version.id, buffer, version.document.fileType);
        // Başarılı oldu — durumu READY'ye çekip varsa eski hata
        // mesajını temizliyoruz. Bu olmadan, önceden ERROR olarak
        // işaretlenmiş bir doküman başarıyla yeniden işlense bile
        // ekranda hâlâ "hata" görünmeye devam ediyordu.
        await this.prisma.document.update({
          where: { id: version.document.id },
          data: { status: 'READY', errorMessage: null },
        });
      } catch (e) {
        this.logger.error(`Versiyon ${version.id} (${version.document.title}) yeniden işlenemedi: ${e}`);
        await this.prisma.document
          .update({
            where: { id: version.document.id },
            data: { status: 'ERROR', errorMessage: String(e).slice(0, 500) },
          })
          .catch(() => {});
      }
      done++;
      onProgress?.(done, targets.length, version.document.title);
    }

    return { total: targets.length, processed: done, skipped: versions.length - targets.length };
  }
}
