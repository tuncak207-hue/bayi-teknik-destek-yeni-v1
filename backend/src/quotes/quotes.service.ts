import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../common/prisma/prisma.service';
import { StorageService } from '../common/storage/storage.service';
import { NotificationsService } from '../notifications/notifications.service';

@Injectable()
export class QuotesService {
  constructor(
    private prisma: PrismaService,
    private storage: StorageService,
    private notifications: NotificationsService,
  ) {}

  listPriceItems() {
    return this.prisma.priceListItem.findMany({ orderBy: [{ category: 'asc' }, { name: 'asc' }] });
  }

  /**
   * Excel'den kopyalanıp yapıştırılan (Tab ile ayrılmış) ham metni fiyat
   * listesine aktarır. Format: Marka \t Kod \t Açıklama \t (boş) \t Fiyat
   * Kategori başlığı satırları (sadece ilk sütunu dolu olan satırlar)
   * otomatik tespit edilip sonraki ürünlere kategori olarak atanır.
   * Excel'den kopyalanan çok satırlı açıklamalar (tırnak içinde) doğru
   * şekilde tek hücre olarak okunur.
   */
  async bulkImportPriceList(rawText: string) {
    const rows = this.parseTsv(rawText);
    let currentCategory: string | undefined;
    const created: { name: string; brand?: string; code?: string; category?: string; unitPrice: number }[] = [];

    for (const row of rows) {
      const cells = row.map((c) => c.trim());
      // Kategori başlığı: ilk hücre dolu, geri kalanların hepsi boş.
      const nonEmptyCount = cells.filter((c) => c.length > 0).length;
      if (nonEmptyCount === 1 && cells[0]) {
        currentCategory = cells[0];
        continue;
      }
      if (cells.length < 3) continue;

      const [brand, code, description, , rawPrice] = cells;
      if (!description) continue;

      const priceCell = rawPrice || cells[cells.length - 1];
      const unitPrice = this.parseEuroPrice(priceCell);
      if (unitPrice === null) continue;

      created.push({ name: description, brand: brand || undefined, code: code || undefined, category: currentCategory, unitPrice });
    }

    if (created.length === 0) {
      return { imported: 0, message: 'Hiçbir geçerli satır bulunamadı. Format ve fiyat sütununu kontrol edin.' };
    }

    await this.prisma.priceListItem.createMany({
      data: created.map((c) => ({ name: c.name, brand: c.brand, code: c.code, category: c.category, unit: 'adet', unitPrice: c.unitPrice })),
    });

    return { imported: created.length };
  }

  /** "€ 1.530,00" -> 1530.00 gibi Avrupa/Türkçe fiyat biçimini sayıya çevirir. */
  private parseEuroPrice(raw: string): number | null {
    const cleaned = raw.replace(/[€\s]/g, '').replace(/\./g, '').replace(',', '.');
    const value = parseFloat(cleaned);
    return isNaN(value) ? null : value;
  }

  /**
   * Basit ama sağlam bir TSV ayrıştırıcı — Excel'den kopyalanan, tırnak
   * içine alınmış ve İÇİNDE SATIR SONU (newline) barındıran hücreleri
   * (örn. çok satırlı açıklamalar) doğru şekilde TEK hücre olarak okur.
   */
  private parseTsv(text: string): string[][] {
    const rows: string[][] = [];
    let row: string[] = [];
    let cell = '';
    let inQuotes = false;
    let i = 0;

    while (i < text.length) {
      const char = text[i];

      if (inQuotes) {
        if (char === '"') {
          if (text[i + 1] === '"') {
            cell += '"';
            i += 2;
            continue;
          }
          inQuotes = false;
          i++;
          continue;
        }
        cell += char;
        i++;
        continue;
      }

      if (char === '"' && cell.length === 0) {
        inQuotes = true;
        i++;
        continue;
      }
      if (char === '\t') {
        row.push(cell);
        cell = '';
        i++;
        continue;
      }
      if (char === '\r') {
        i++;
        continue;
      }
      if (char === '\n') {
        row.push(cell);
        cell = '';
        if (row.some((c) => c.trim().length > 0)) rows.push(row);
        row = [];
        i++;
        continue;
      }
      cell += char;
      i++;
    }
    row.push(cell);
    if (row.some((c) => c.trim().length > 0)) rows.push(row);

    return rows;
  }

  createPriceItem(name: string, unit: string, unitPrice: number, category?: string, brand?: string, code?: string) {
    return this.prisma.priceListItem.create({ data: { name, unit, unitPrice, category, brand, code } });
  }

  updatePriceItem(id: string, name: string, unit: string, unitPrice: number, category?: string, brand?: string, code?: string) {
    return this.prisma.priceListItem.update({ where: { id }, data: { name, unit, unitPrice, category, brand, code } });
  }

  async deletePriceItem(id: string) {
    await this.prisma.priceListItem.delete({ where: { id } });
    return { success: true };
  }

  /** Tüm katalogu temizler — yeniden toplu içe aktarmadan önce kullanılabilir. */
  async deleteAllPriceItems() {
    const result = await this.prisma.priceListItem.deleteMany();
    return { deleted: result.count };
  }

  async uploadPriceListDocument(file: Express.Multer.File) {
    const key = await this.storage.upload(file.buffer, file.originalname, file.mimetype, 'price-list');
    return this.prisma.priceListDocument.upsert({
      where: { id: 1 },
      create: { id: 1, fileUrl: key },
      update: { fileUrl: key },
    });
  }

  async getPriceListDocumentUrl() {
    const doc = await this.prisma.priceListDocument.findUnique({ where: { id: 1 } });
    if (!doc?.fileUrl) return null;
    return this.storage.getSignedUrl(doc.fileUrl);
  }

  async createQuote(
    dealerId: string,
    params: {
      title: string;
      customerName?: string;
      customerPhone?: string;
      province?: string;
      district?: string;
      items: { priceListItemId: string; quantity: number }[];
    },
  ) {
    const itemIds = params.items.map((i) => i.priceListItemId);
    const priceItems = await this.prisma.priceListItem.findMany({ where: { id: { in: itemIds } } });
    const priceMap = new Map<string, { name: string; unit: string; unitPrice: number }>(priceItems.map((p) => [p.id, p]));

    const computedItems = params.items.map((i) => {
      const priceItem = priceMap.get(i.priceListItemId);
      if (!priceItem) throw new NotFoundException(`Fiyat listesinde bulunamayan bir kalem seçildi.`);
      const subtotal = priceItem.unitPrice * i.quantity;
      return { name: priceItem.name, unit: priceItem.unit, quantity: i.quantity, unitPrice: priceItem.unitPrice, subtotal };
    });

    const totalAmount = computedItems.reduce((sum, i) => sum + i.subtotal, 0);

    return this.prisma.quoteRequest.create({
      data: {
        dealerId,
        title: params.title,
        customerName: params.customerName,
        customerPhone: params.customerPhone,
        province: params.province,
        district: params.district,
        items: computedItems,
        totalAmount,
      },
    });
  }

  listForDealer(dealerId: string) {
    return this.prisma.quoteRequest.findMany({ where: { dealerId }, orderBy: { createdAt: 'desc' } });
  }

  listAll() {
    return this.prisma.quoteRequest.findMany({
      include: { dealer: { select: { firstName: true, lastName: true, company: true } } },
      orderBy: { createdAt: 'desc' },
    });
  }

  async get(id: string, dealerId: string, checkOwnership = true) {
    const quote = await this.prisma.quoteRequest.findUnique({ where: { id } });
    if (!quote) throw new NotFoundException('Teklif bulunamadı.');
    if (checkOwnership && quote.dealerId !== dealerId) throw new ForbiddenException('Bu teklife erişiminiz yok.');
    return quote;
  }

  /** Bayi kendi teklifini düzenler — fiyatlar yine kataloğun güncel halinden yeniden hesaplanır. */
  async updateQuote(
    id: string,
    dealerId: string,
    params: {
      title: string;
      customerName?: string;
      customerPhone?: string;
      province?: string;
      district?: string;
      items: { priceListItemId: string; quantity: number }[];
    },
  ) {
    await this.get(id, dealerId);

    const itemIds = params.items.map((i) => i.priceListItemId);
    const priceItems = await this.prisma.priceListItem.findMany({ where: { id: { in: itemIds } } });
    const priceMap = new Map<string, { name: string; unit: string; unitPrice: number }>(priceItems.map((p) => [p.id, p]));

    const computedItems = params.items.map((i) => {
      const priceItem = priceMap.get(i.priceListItemId);
      if (!priceItem) throw new NotFoundException(`Fiyat listesinde bulunamayan bir kalem seçildi.`);
      const subtotal = priceItem.unitPrice * i.quantity;
      return { name: priceItem.name, unit: priceItem.unit, quantity: i.quantity, unitPrice: priceItem.unitPrice, subtotal };
    });
    const totalAmount = computedItems.reduce((sum, i) => sum + i.subtotal, 0);

    return this.prisma.quoteRequest.update({
      where: { id },
      data: {
        title: params.title,
        customerName: params.customerName,
        customerPhone: params.customerPhone,
        province: params.province,
        district: params.district,
        items: computedItems,
        totalAmount,
      },
    });
  }

  async delete(id: string, dealerId: string) {
    await this.get(id, dealerId);
    await this.prisma.quoteRequest.delete({ where: { id } });
    return { success: true };
  }

  // ÖNEMLİ DÜZELTME: "teklif durumu değişince hiçbir bildirim
  // gönderilmiyor" — diğer tüm modüllerde (randevu, teknik destek,
  // eğitim vb.) durum değişince bayiye bildirim gidiyordu, teklifte hiç
  // yoktu. Sadece bayinin ilgileneceği ACCEPTED/REJECTED için gönderiliyor
  // (DRAFT/SENT, bayinin kendi eylemi olduğu için gereksiz).
  async updateStatus(id: string, status: string) {
    const updated = await this.prisma.quoteRequest.update({ where: { id }, data: { status: status as any } });
    if (status === 'ACCEPTED' || status === 'REJECTED') {
      await this.notifications.notifyUser(
        updated.dealerId,
        'quote_status_changed',
        status === 'ACCEPTED' ? 'Teklifiniz Onaylandı' : 'Teklifiniz Reddedildi',
        `"${updated.title}" teklifiniz için durum güncellendi.`,
        { quoteId: id },
      );
    }
    return updated;
  }
}
