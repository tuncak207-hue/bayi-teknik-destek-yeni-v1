import { Injectable, ForbiddenException, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../common/prisma/prisma.service';
import { StorageService } from '../common/storage/storage.service';

/** Standart yangın alarm paneli devreye alma kontrol listesi maddeleri. */
const DEFAULT_CHECKLIST_ITEMS: string[] = [
  'Panel montajı sağlam ve erişilebilir konumda',
  'Ana besleme gerilimi doğrulandı (230V AC)',
  'Akü bağlantıları ve kapasitesi kontrol edildi',
  'Tüm loop/zon kablolamaları uçtan uca test edildi',
  'Adreslenebilir dedektörler panelde görünüyor ve doğru adreslenmiş',
  'Sounder / alarm cihazları test edildi (sesli/ışıklı uyarı)',
  'Manuel ihbar butonları (break-glass) test edildi',
  'Ana şebeke kesildiğinde akü ile bekleme süresi test edildi',
  'Hata (fault) simülasyonu yapıldı, panel doğru uyarı verdi',
  'Merkezi izleme/monitörlü hat bağlantısı test edildi (varsa)',
  'Kontrol paneli üzerindeki tüm etiketler ve zon isimleri güncel',
  'Devreye alma tarihi ve teknisyen bilgisi panel logbook\'una işlendi',
];

@Injectable()
export class CommissioningService {
  constructor(private prisma: PrismaService, private storage: StorageService) {}

  /** Boş, standart bir kontrol listesi şablonu döner (mobil bunu form olarak gösterir). */
  getTemplate() {
    return { items: DEFAULT_CHECKLIST_ITEMS.map((label) => ({ label, checked: false })) };
  }

  create(dealerId: string, params: {
    siteName: string;
    panelBrand: string;
    panelModel: string;
    serialNumber?: string;
    items: Array<{ label: string; checked: boolean }>;
    notes?: string;
  }) {
    const allChecked = params.items.every((i) => i.checked);
    return this.prisma.commissioningReport.create({
      data: {
        dealerId,
        siteName: params.siteName,
        panelBrand: params.panelBrand,
        panelModel: params.panelModel,
        serialNumber: params.serialNumber,
        items: params.items,
        notes: params.notes,
        completedAt: allChecked ? new Date() : null,
      },
    });
  }

  /**
   * Kullanıcı isteği: "Dijital Cihaz Pasaportu" — QR kodu taranan cihazın
   * TÜM geçmişini (devreye alma + bağlı bakım kayıtları + teknik destek
   * talepleri) tarih sırasıyla döner. BİLİNÇLİ OLARAK dealerId kontrolü
   * YAPILMIYOR — "yıllar sonra bile, başka bir bayi olsa bile" geçmişi
   * görebilmesi gerekiyor (kullanıcı isteği). Sadece giriş yapmış (JWT
   * doğrulanmış) bir kullanıcı olması yeterli — tamamen herkese açık
   * değil, ama bayi sınırlaması da yok.
   */
  async getByQrCode(qrCode: string) {
    const report = await this.prisma.commissioningReport.findUnique({
      where: { deviceQrCode: qrCode },
      include: {
        dealer: { select: { firstName: true, lastName: true, company: true } },
        maintenanceRecords: {
          orderBy: { performedAt: 'desc' },
          include: { createdBy: { select: { firstName: true, lastName: true, company: true } } },
        },
        supportTickets: {
          orderBy: { createdAt: 'desc' },
          select: { id: true, description: true, status: true, priority: true, createdAt: true },
        },
      },
    });
    if (!report) throw new NotFoundException('Bu QR koda ait bir cihaz kaydı bulunamadı.');
    return report;
  }

  listForDealer(dealerId: string) {
    return this.prisma.commissioningReport.findMany({
      where: { dealerId },
      orderBy: { createdAt: 'desc' },
    });
  }

  async get(id: string, dealerId: string) {
    const report = await this.prisma.commissioningReport.findUnique({ where: { id } });
    if (!report) throw new NotFoundException('Rapor bulunamadı.');
    if (report.dealerId !== dealerId) throw new ForbiddenException('Bu rapor size ait değil.');
    return report;
  }

  /** Kullanıcı isteği: "Devreye Alma raporunu düzenlemeli ve silmeli." */
  async delete(id: string, dealerId: string) {
    await this.get(id, dealerId);
    await this.prisma.commissioningReport.delete({ where: { id } });
    return { success: true };
  }

  /**
   * Rapor içeriği düzenlenebilmeli — kullanıcı isteği. ÖNEMLİ: Kullanıcı
   * isteği üzerine düzenleme, raporun oluşturulmasından
   * sonraki belirli bir süreyle (48 saat) sınırlandırıldı — bu süreden
   * sonra rapor kalıcı hale gelir, düzenlenemez.
   */
  private static readonly EDIT_WINDOW_HOURS = 48;

  async update(
    id: string,
    dealerId: string,
    params: Partial<{
      siteName: string;
      panelBrand: string;
      panelModel: string;
      items: Array<{ label: string; checked: boolean }>;
      notes: string;
      customerName: string;
    }>,
  ) {
    const existing = await this.get(id, dealerId);
    const hoursPassed = (Date.now() - existing.createdAt.getTime()) / 3600000;
    if (hoursPassed > CommissioningService.EDIT_WINDOW_HOURS) {
      throw new ForbiddenException(
        `Bu rapor oluşturulduktan sonra sadece ${CommissioningService.EDIT_WINDOW_HOURS} saat içinde düzenlenebilir.`,
      );
    }
    const allChecked = params.items ? params.items.every((i) => i.checked) : undefined;
    return this.prisma.commissioningReport.update({
      where: { id },
      data: {
        ...(params.siteName !== undefined && { siteName: params.siteName }),
        ...(params.panelBrand !== undefined && { panelBrand: params.panelBrand }),
        ...(params.panelModel !== undefined && { panelModel: params.panelModel }),
        ...(params.items !== undefined && { items: params.items }),
        ...(params.notes !== undefined && { notes: params.notes }),
        ...(params.customerName !== undefined && { customerName: params.customerName }),
        ...(allChecked !== undefined && { completedAt: allChecked ? new Date() : null }),
      },
    });
  }

  /** Müşteri imzasını (ekranda çizilip PNG olarak yüklenen) rapora ekler. */
  async attachSignature(id: string, dealerId: string, file: Express.Multer.File) {
    await this.get(id, dealerId);
    const key = await this.storage.upload(file.buffer, file.originalname, file.mimetype, 'commissioning-signatures');
    return this.prisma.commissioningReport.update({ where: { id }, data: { signatureUrl: key } });
  }

  async getSignedSignatureUrl(id: string, dealerId: string) {
    const report = await this.get(id, dealerId);
    if (!report.signatureUrl) return null;
    return this.storage.getSignedUrl(report.signatureUrl);
  }
}
