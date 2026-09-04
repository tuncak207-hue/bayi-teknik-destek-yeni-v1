import { Injectable, NotFoundException, Logger } from '@nestjs/common';
import { PrismaService } from '../common/prisma/prisma.service';
import { StorageService } from '../common/storage/storage.service';
import { RagIngestionService } from '../rag/rag-ingestion.service';
import { NotificationsService } from '../notifications/notifications.service';
import { TechnicalMemoryService } from '../ai/technical-memory.service';
import { UploadDocumentDto } from './dto/upload-document.dto';

@Injectable()
export class DocumentsService {
  private readonly logger = new Logger(DocumentsService.name);

  constructor(
    private prisma: PrismaService,
    private storage: StorageService,
    private ragIngestion: RagIngestionService,
    private notifications: NotificationsService,
    private technicalMemory: TechnicalMemoryService,
  ) {}

  async upload(dto: UploadDocumentDto, file: Express.Multer.File) {
    const fileKey = await this.storage.upload(file.buffer, file.originalname, file.mimetype);

    let document = dto.documentId
      ? await this.prisma.document.findUnique({ where: { id: dto.documentId } })
      : null;
    const isNewVersionOfExisting = !!document;

    if (!document) {
      document = await this.prisma.document.create({
        data: {
          brand: dto.brand,
          model: dto.model,
          title: dto.title,
          fileType: file.mimetype,
          fileUrl: fileKey,
          status: 'PROCESSING',
        },
      });
    } else {
      await this.prisma.document.update({
        where: { id: document.id },
        data: { status: 'PROCESSING' },
      });
    }

    // Yeni versiyon eklendiğinde önceki versiyonları "current" olmaktan çıkar
    await this.prisma.documentVersion.updateMany({
      where: { documentId: document.id },
      data: { isCurrent: false },
    });

    const version = await this.prisma.documentVersion.create({
      data: {
        documentId: document.id,
        version: dto.version,
        isCurrent: true,
        fileUrl: fileKey,
      },
    });

    // Mevcut bir dokümana yeni versiyon eklendiyse, bu dokümanı daha önce
    // favorileyen bayilere haber ver — sahada eski/hatalı sürümle
    // çalışmalarını önlemek için önemli bir güvenlik bildirimi.
    if (isNewVersionOfExisting) {
      void this.notifyFavoritedBy(document.id, document.title);
      // AI Teknik Soru Hafızası — kullanıcı isteği: "Yeni doküman
      // yüklendi... bu durumda ilgili eski cevaplar otomatik olarak
      // 'yeniden doğrulama gerekli' durumuna alınmalı."
      void this.technicalMemory.markNeedsReverification(document.brand, document.model);
    }

    // Ağır işlem (extract -> OCR -> chunk -> embed) arka planda çalışır.
    // Prodüksiyonda bu bir queue (BullMQ/SQS) ile yapılmalı; burada basit async tetikleme.
    this.ragIngestion
      .processDocumentVersion(version.id, file.buffer, file.mimetype)
      .then(async (pageCount) => {
        await this.prisma.documentVersion.update({
          where: { id: version.id },
          data: { pageCount },
        });
        await this.prisma.document.update({
          where: { id: document!.id },
          data: { status: 'READY' },
        });
      })
      .catch(async (err) => {
        this.logger.error(`Doküman işleme hatası: ${err.message}`, err.stack);
        await this.prisma.document.update({
          where: { id: document!.id },
          data: { status: 'ERROR', errorMessage: err.message },
        });
      });

    return { documentId: document.id, versionId: version.id, status: 'PROCESSING' };
  }

  /**
   * Kullanıcı isteği: "AI teknik asistan sadece dokümana değil, bu URL
   * linkine de baksın" — admin panelden eklenen bir web sayfasını
   * indirir, DOSYA YÜKLEMEYLE AYNI RAG işleme hattından (extract ->
   * chunk -> embed) geçirir. Böylece AI cevap üretirken bu içeriği de
   * dokümanlarla birlikte arayıp referans alabiliyor — cevap üretme
   * kodunda HİÇBİR değişiklik gerekmiyor.
   */
  async uploadFromUrl(dto: { url: string; brand: string; model: string; title: string; version: string }) {
    let html: string;
    try {
      const res = await fetch(dto.url, { signal: AbortSignal.timeout(20_000) });
      if (!res.ok) throw new Error(`Sayfa alınamadı (HTTP ${res.status})`);
      html = await res.text();
    } catch (err: any) {
      throw new Error(`URL indirilemedi: ${err.message}`);
    }
    const buffer = Buffer.from(html, 'utf-8');

    const document = await this.prisma.document.create({
      data: {
        brand: dto.brand,
        model: dto.model,
        title: dto.title,
        fileType: 'text/html',
        // Dosyalarda R2 depolama anahtarı tutulur, burada ise DOĞRUDAN
        // kaynak URL — 'http' ile başlaması, bunun bir web linki
        // olduğunu (indirilmiş bir dosya değil) ayırt etmeye yarıyor.
        fileUrl: dto.url,
        status: 'PROCESSING',
      },
    });

    const version = await this.prisma.documentVersion.create({
      data: {
        documentId: document.id,
        version: dto.version,
        isCurrent: true,
        fileUrl: dto.url,
      },
    });

    this.ragIngestion
      .processDocumentVersion(version.id, buffer, 'text/html')
      .then(async (pageCount) => {
        await this.prisma.documentVersion.update({ where: { id: version.id }, data: { pageCount } });
        await this.prisma.document.update({ where: { id: document.id }, data: { status: 'READY' } });
      })
      .catch(async (err) => {
        this.logger.error(`URL işleme hatası: ${err.message}`, err.stack);
        await this.prisma.document.update({
          where: { id: document.id },
          data: { status: 'ERROR', errorMessage: err.message },
        });
      });

    return { documentId: document.id, versionId: version.id, status: 'PROCESSING' };
  }

  private async notifyFavoritedBy(documentId: string, title: string) {
    const favorites = await this.prisma.favorite.findMany({
      where: { documentId },
      select: { userId: true },
    });
    await Promise.all(
      favorites.map((f) =>
        this.notifications.notifyUser(
          f.userId,
          'new_document',
          'Doküman Güncellendi',
          `"${title}" için yeni bir versiyon yüklendi. Favorilediğiniz dokümanı kontrol edin.`,
          { documentId },
        ),
      ),
    );
  }

  list() {
    return this.prisma.document.findMany({
      include: { versions: { orderBy: { createdAt: 'desc' } } },
      orderBy: { createdAt: 'desc' },
    });
  }

  async get(id: string) {
    const doc = await this.prisma.document.findUnique({
      where: { id },
      include: { versions: true },
    });
    if (!doc) throw new NotFoundException('Doküman bulunamadı.');
    return doc;
  }

  async delete(id: string) {
    await this.get(id);
    // ÖNEMLİ: Şema düzeyindeki "onDelete: Cascade" beklenildiği gibi
    // devreye girmediği için (bkz. rag-ingestion.service.ts'deki aynı
    // düzeltme), ilgili eski alıntı (MessageCitation) kayıtlarını,
    // dokümanı silmeden önce kod tarafında açıkça temizliyoruz.
    await this.prisma.messageCitation.deleteMany({
      where: { documentChunk: { documentVersion: { documentId: id } } },
    });
    await this.prisma.document.delete({ where: { id } });
    return { deleted: true };
  }

  /** Admin dokümanın başlık/marka/model bilgisini düzenler (dosyanın kendisi değişmez). */
  async update(id: string, data: Partial<{ title: string; brand: string; model: string }>) {
    await this.get(id);
    return this.prisma.document.update({ where: { id }, data });
  }

  async getSignedFileUrl(documentId: string) {
    const doc = await this.get(documentId);
    const current = doc.versions.find((v) => v.isCurrent) ?? doc.versions[0];
    if (!current) throw new NotFoundException('Bu dokümanın bir versiyonu yok.');
    return this.storage.getSignedUrl(current.fileUrl);
  }

  /** Belirli bir (eski) versiyonun imzalı URL'sini döner — versiyon geçmişini görüntülemek için. */
  async getSignedUrlForVersion(documentId: string, versionId: string) {
    const doc = await this.get(documentId);
    const version = doc.versions.find((v) => v.id === versionId);
    if (!version) throw new NotFoundException('Bu versiyon bulunamadı.');
    return this.storage.getSignedUrl(version.fileUrl);
  }
}
