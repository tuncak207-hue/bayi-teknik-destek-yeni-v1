import { Injectable, ForbiddenException, NotFoundException } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { PrismaService } from '../common/prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { StorageService } from '../common/storage/storage.service';

// Bir SlaSetting kaydı yoksa kullanılan mantıklı varsayılanlar (dakika).
const DEFAULT_SLA: Record<string, { response: number; resolution: number }> = {
  EMERGENCY: { response: 15, resolution: 240 }, // 15 dk yanıt, 4 saat çözüm
  HIGH: { response: 60, resolution: 480 }, // 1 saat yanıt, 8 saat çözüm
  NORMAL: { response: 240, resolution: 1440 }, // 4 saat yanıt, 24 saat çözüm
  LOW: { response: 480, resolution: 2880 }, // 8 saat yanıt, 48 saat çözüm
};

@Injectable()
export class SupportTicketsService {
  constructor(
    private prisma: PrismaService,
    private notifications: NotificationsService,
    private storage: StorageService,
  ) {}

  private async getSlaFor(priority: string) {
    const custom = await this.prisma.slaSetting.findUnique({ where: { priority: priority as any } });
    if (custom) return { response: custom.responseMinutes, resolution: custom.resolutionMinutes };
    return DEFAULT_SLA[priority] ?? DEFAULT_SLA.NORMAL;
  }

  /** Admin: öncelik bazında SLA sürelerini görüntüler (tanımlı olanlar + varsayılanlar). */
  async getSlaSettings() {
    const custom = await this.prisma.slaSetting.findMany();
    const customMap = new Map<string, { responseMinutes: number; resolutionMinutes: number }>(
      custom.map((c) => [c.priority, c]),
    );
    return Object.entries(DEFAULT_SLA).map(([priority, def]) => {
      const override = customMap.get(priority as any);
      return {
        priority,
        responseMinutes: override?.responseMinutes ?? def.response,
        resolutionMinutes: override?.resolutionMinutes ?? def.resolution,
        isCustom: !!override,
      };
    });
  }

  /** Admin: bir önceliğin SLA süresini günceller/oluşturur. */
  async updateSlaSetting(priority: string, responseMinutes: number, resolutionMinutes: number) {
    return this.prisma.slaSetting.upsert({
      where: { priority: priority as any },
      create: { priority: priority as any, responseMinutes, resolutionMinutes },
      update: { responseMinutes, resolutionMinutes },
    });
  }

  /** Bir kaydın SLA durumunu (kalan süre, aşılıp aşılmadığı) hesaplar — anlık, kayıtlı değil. */
  private computeSlaStatus(ticket: { createdAt: Date; firstRespondedAt: Date | null; status: string; slaResponseMinutes: number | null; slaResolutionMinutes: number | null }) {
    if (ticket.status === 'RESOLVED' || ticket.status === 'CLOSED') {
      return { responseRemainingMinutes: null, resolutionRemainingMinutes: null, responseBreached: false, resolutionBreached: false };
    }
    const now = Date.now();
    const createdMs = ticket.createdAt.getTime();

    const responseDeadline = ticket.slaResponseMinutes != null ? createdMs + ticket.slaResponseMinutes * 60000 : null;
    const resolutionDeadline = ticket.slaResolutionMinutes != null ? createdMs + ticket.slaResolutionMinutes * 60000 : null;

    const responseRemainingMinutes =
      !ticket.firstRespondedAt && responseDeadline ? Math.round((responseDeadline - now) / 60000) : null;
    const resolutionRemainingMinutes = resolutionDeadline ? Math.round((resolutionDeadline - now) / 60000) : null;

    return {
      responseRemainingMinutes,
      resolutionRemainingMinutes,
      responseBreached: responseRemainingMinutes !== null && responseRemainingMinutes < 0,
      resolutionBreached: resolutionRemainingMinutes !== null && resolutionRemainingMinutes < 0,
    };
  }

  /** Ticket nesnesine SLA durumunu ekler — liste/detay uç noktalarında kullanılır. */
  private withSlaStatus(ticket: any) {
    return { ...ticket, slaStatus: this.computeSlaStatus(ticket) };
  }

  async create(
    dealerId: string,
    params: {
      productName?: string;
      productModel?: string;
      serialNumber?: string;
      location?: string;
      description: string;
      isEmergency?: boolean;
      commissioningReportId?: string;
    },
  ) {
    const isEmergency = params.isEmergency === true;
    const priority = isEmergency ? 'EMERGENCY' : 'NORMAL';
    const sla = await this.getSlaFor(priority);

    const ticket = await this.prisma.supportTicket.create({
      data: {
        dealerId,
        productName: params.productName,
        productModel: params.productModel,
        serialNumber: params.serialNumber,
        location: params.location,
        description: params.description,
        isEmergency,
        priority,
        slaResponseMinutes: sla.response,
        slaResolutionMinutes: sla.resolution,
        commissioningReportId: params.commissioningReportId,
      },
    });

    const dealer = await this.prisma.user.findUnique({ where: { id: dealerId } });
    const dealerName = dealer ? `${dealer.firstName} ${dealer.lastName} (${dealer.company})` : 'Bir bayi';

    const staff = await this.prisma.user.findMany({
      where: { role: { in: ['ADMIN', 'ENGINEER'] } },
      select: { id: true },
    });
    await Promise.all(
      staff.map((s) =>
        this.notifications.notifyUser(
          s.id,
          isEmergency ? 'emergency_ticket' : 'ticket_created',
          isEmergency ? '🔴 ACİL Teknik Destek Talebi' : 'Yeni Teknik Destek Kaydı',
          `${dealerName} — ${params.productName ?? ''} ${params.productModel ?? ''}: ${params.description.slice(0, 80)}`,
          { ticketId: ticket.id },
        ),
      ),
    );

    return ticket;
  }

  async attachFile(ticketId: string, dealerId: string, file: Express.Multer.File) {
    const ticket = await this.get(ticketId, dealerId, false);
    const key = await this.storage.upload(file.buffer, file.originalname, file.mimetype, 'support-tickets');
    const existing = (ticket.attachmentUrls as string[] | null) ?? [];
    return this.prisma.supportTicket.update({
      where: { id: ticketId },
      data: { attachmentUrls: [...existing, key] },
    });
  }

  async getSignedAttachmentUrls(ticketId: string, dealerId: string) {
    const ticket = await this.get(ticketId, dealerId, false);
    const keys = (ticket.attachmentUrls as string[] | null) ?? [];
    return Promise.all(keys.map((k) => this.storage.getSignedUrl(k)));
  }

  listForDealer(dealerId: string) {
    return this.prisma.supportTicket
      .findMany({
        where: { dealerId },
        orderBy: [{ isEmergency: 'desc' }, { createdAt: 'desc' }],
      })
      .then((list) => list.map((t) => this.withSlaStatus(t)));
  }

  listAll(status?: string) {
    return this.prisma.supportTicket
      .findMany({
        where: status ? { status: status as any } : undefined,
        include: { dealer: { select: { firstName: true, lastName: true, company: true, phone: true } } },
        orderBy: [{ isEmergency: 'desc' }, { priority: 'desc' }, { createdAt: 'desc' }],
      })
      .then((list) => list.map((t) => this.withSlaStatus(t)));
  }

  async get(id: string, userId: string, checkOwnership = true) {
    const ticket = await this.prisma.supportTicket.findUnique({ where: { id } });
    if (!ticket) throw new NotFoundException('Teknik destek kaydı bulunamadı.');
    if (checkOwnership && ticket.dealerId !== userId) throw new ForbiddenException('Bu kayda erişiminiz yok.');
    return this.withSlaStatus(ticket);
  }

  async assignEngineer(ticketId: string, engineerId: string) {
    const existing = await this.prisma.supportTicket.findUnique({ where: { id: ticketId } });
    const ticket = await this.prisma.supportTicket.update({
      where: { id: ticketId },
      data: {
        assignedEngineerId: engineerId,
        status: 'IN_PROGRESS',
        // İlk kez atanıyorsa "ilk yanıt zamanı" burada işaretlenir — SLA
        // yanıt süresi hesaplaması bunu esas alır.
        ...(existing?.firstRespondedAt ? {} : { firstRespondedAt: new Date() }),
      },
    });
    await this.notifications.notifyUser(
      engineerId,
      'ticket_assigned',
      'Size Yeni Bir Kayıt Atandı',
      `${ticket.productName ?? 'Teknik destek'} kaydı size atandı.`,
      { ticketId },
    );
    return ticket;
  }

  async updateStatus(ticketId: string, status: string) {
    const existing = await this.prisma.supportTicket.findUnique({ where: { id: ticketId } });
    const ticket = await this.prisma.supportTicket.update({
      where: { id: ticketId },
      data: {
        status: status as any,
        ...(existing?.firstRespondedAt ? {} : { firstRespondedAt: new Date() }),
      },
    });
    await this.notifications.notifyUser(
      ticket.dealerId,
      'ticket_status_changed',
      'Teknik Destek Kaydınız Güncellendi',
      `"${ticket.productName ?? ticket.description.slice(0, 40)}" kaydınızın durumu güncellendi.`,
      { ticketId },
    );
    return ticket;
  }

  /** Bayi ya da admin, kaydın temel bilgilerini düzenler. */
  async updateTicket(
    ticketId: string,
    userId: string,
    isStaff: boolean,
    params: {
      productName?: string;
      productModel?: string;
      serialNumber?: string;
      location?: string;
      description?: string;
    },
  ) {
    const ticket = await this.get(ticketId, userId, !isStaff);
    return this.prisma.supportTicket.update({
      where: { id: ticket.id },
      data: {
        ...(params.productName !== undefined && { productName: params.productName }),
        ...(params.productModel !== undefined && { productModel: params.productModel }),
        ...(params.serialNumber !== undefined && { serialNumber: params.serialNumber }),
        ...(params.location !== undefined && { location: params.location }),
        ...(params.description !== undefined && { description: params.description }),
      },
    });
  }

  /** Bayi kendi kaydını, admin herhangi bir kaydı silebilir. */
  async deleteTicket(ticketId: string, userId: string, isStaff: boolean) {
    await this.get(ticketId, userId, !isStaff);
    await this.prisma.supportTicket.delete({ where: { id: ticketId } });
    return { success: true };
  }

  // ============================================================
  // FAZ 3: Önce/Sonra Fotoğraf
  // ============================================================

  /** Saha işlemi öncesi/sonrası fotoğraf ekler — aynı kayıt altında gruplanır. */
  async addPhoto(ticketId: string, userId: string, type: 'BEFORE' | 'AFTER', file: Express.Multer.File) {
    await this.get(ticketId, userId, false);
    const key = await this.storage.upload(file.buffer, file.originalname, file.mimetype, 'ticket-photos');
    return this.prisma.ticketPhoto.create({ data: { ticketId, type, url: key } });
  }

  /** Önce/sonra fotoğrafları gruplu olarak (imzalı URL'lerle) döner — karşılaştırma ekranı için. */
  async getPhotoComparison(ticketId: string) {
    const photos = await this.prisma.ticketPhoto.findMany({ where: { ticketId }, orderBy: { createdAt: 'asc' } });
    const withUrls = await Promise.all(
      photos.map(async (p) => ({ ...p, signedUrl: await this.storage.getSignedUrl(p.url) })),
    );
    return {
      before: withUrls.filter((p) => p.type === 'BEFORE'),
      after: withUrls.filter((p) => p.type === 'AFTER'),
    };
  }

  // ============================================================
  // FAZ 3: Teknik Ölçüm Sistemi
  // ============================================================

  /** Admin: ölçüm türü tanımlar (adı, birimi, kabul edilebilir min/max aralığı). */
  createMeasurementType(name: string, unit: string, minValue?: number, maxValue?: number) {
    return this.prisma.measurementType.create({ data: { name, unit, minValue, maxValue } });
  }

  listMeasurementTypes() {
    return this.prisma.measurementType.findMany({ orderBy: { name: 'asc' } });
  }

  /**
   * Mühendis saha sırasında ölçüm girer. Değer, tanımlı min/max aralığının
   * dışındaysa `isOutOfRange` işaretlenir ve anlık uyarı verilmesi için
   * bilgi döndürülür (kullanıcı isteği: "girilen değer limit dışındaysa
   * anlık uyarı göster").
   */
  async addMeasurement(ticketId: string, measurementTypeId: string, value: number) {
    const ticket = await this.prisma.supportTicket.findUnique({ where: { id: ticketId } });
    const type = await this.prisma.measurementType.findUnique({ where: { id: measurementTypeId } });
    if (!ticket || !type) throw new NotFoundException('Kayıt veya ölçüm türü bulunamadı.');

    const isOutOfRange = (type.minValue != null && value < type.minValue) || (type.maxValue != null && value > type.maxValue);

    return this.prisma.ticketMeasurement.create({
      data: {
        ticketId,
        measurementTypeId,
        value,
        isOutOfRange,
        serialNumber: ticket.serialNumber,
      },
      include: { measurementType: true },
    });
  }

  /** Bir kaydın tüm ölçümlerini döner. */
  getMeasurementsForTicket(ticketId: string) {
    return this.prisma.ticketMeasurement.findMany({
      where: { ticketId },
      include: { measurementType: true },
      orderBy: { createdAt: 'asc' },
    });
  }

  /**
   * Aynı ürünün (seri numarasına göre) geçmiş TÜM ölçümlerini döner —
   * kullanıcı isteği: "ölçüm geçmişini ürün ve seri numarası bazında
   * sakla", "zaman içerisindeki değişimleri grafik olarak göster".
   */
  getMeasurementHistoryBySerial(serialNumber: string) {
    return this.prisma.ticketMeasurement.findMany({
      where: { serialNumber },
      include: { measurementType: true },
      orderBy: { createdAt: 'asc' },
    });
  }

  // ============================================================
  // FAZ 4: Teknik Destek → Yedek Parça Talebi
  // ============================================================

  /**
   * Ürün, model, seri numarası kaydın kendisinden geliyor — kullanıcı
   * bunları tekrar girmiyor, sadece parça kodu/adı/miktarını giriyor.
   */
  async createSparePartRequest(ticketId: string, requestedById: string, partCode: string | undefined, partName: string, quantity: number) {
    const ticket = await this.prisma.supportTicket.findUnique({ where: { id: ticketId } });
    if (!ticket) throw new NotFoundException('Teknik destek kaydı bulunamadı.');

    const request = await this.prisma.sparePartRequest.create({
      data: { ticketId, requestedById, partCode, partName, quantity },
    });

    const admins = await this.prisma.user.findMany({ where: { role: 'ADMIN' }, select: { id: true } });
    await Promise.all(
      admins.map((a) =>
        this.notifications.notifyUser(
          a.id,
          'ticket_assigned',
          'Yeni Yedek Parça Talebi',
          `${ticket.productName ?? ''} ${ticket.productModel ?? ''} (SN: ${ticket.serialNumber ?? '—'}) için "${partName}" (${quantity} adet) talep edildi.`,
          { ticketId, sparePartRequestId: request.id },
        ),
      ),
    );

    return request;
  }

  /** Kaydın ürün/model/seri bilgisiyle birlikte parça taleplerini döner. */
  async listSparePartRequestsForTicket(ticketId: string) {
    return this.prisma.sparePartRequest.findMany({ where: { ticketId }, orderBy: { createdAt: 'desc' } });
  }

  /** Admin: tüm yedek parça taleplerini, bağlı oldukları kaydın ürün bilgisiyle birlikte döner. */
  listAllSparePartRequests() {
    return this.prisma.sparePartRequest.findMany({
      include: {
        ticket: { select: { productName: true, productModel: true, serialNumber: true, dealer: { select: { firstName: true, lastName: true, company: true } } } },
        requestedBy: { select: { firstName: true, lastName: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  updateSparePartStatus(id: string, status: string) {
    return this.prisma.sparePartRequest.update({ where: { id }, data: { status: status as any } });
  }

  // ============================================================
  // FAZ 4: Teknik Destek Maliyet Analizi
  // ============================================================

  addCost(ticketId: string, category: string, description: string | undefined, amount: number) {
    return this.prisma.ticketCost.create({ data: { ticketId, category: category as any, description, amount } });
  }

  getCostsForTicket(ticketId: string) {
    return this.prisma.ticketCost.findMany({ where: { ticketId }, orderBy: { createdAt: 'asc' } });
  }

  /**
   * Ürün, bayi, bölge (konum metni) ve tarih bazında maliyet raporu.
   * Basit ama esnek: tüm maliyet kayıtlarını ilişkili kaydın bilgileriyle
   * birlikte döner, gruplama admin panelde yapılır (esneklik için).
   */
  async getCostReport(params: { dealerId?: string; productName?: string; from?: string; to?: string }) {
    const costs = await this.prisma.ticketCost.findMany({
      where: {
        createdAt: {
          gte: params.from ? new Date(params.from) : undefined,
          lte: params.to ? new Date(params.to) : undefined,
        },
        ticket: {
          dealerId: params.dealerId,
          productName: params.productName ? { contains: params.productName, mode: 'insensitive' } : undefined,
        },
      },
      include: {
        ticket: {
          select: {
            productName: true,
            location: true,
            dealer: { select: { firstName: true, lastName: true, company: true } },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    const totalByCategory: Record<string, number> = {};
    let grandTotal = 0;
    for (const c of costs) {
      totalByCategory[c.category] = (totalByCategory[c.category] ?? 0) + c.amount;
      grandTotal += c.amount;
    }

    return { costs, totalByCategory, grandTotal };
  }

  /**
   * Her gün çalışır: bir bayinin son 90 günde aynı ürünle ilgili 3+
   * teknik destek talebi olduysa, eğitim öneren kişiselleştirilmiş bir
   * bildirim gönderir (kullanıcı isteği #14 + #16 — herkese aynı
   * bildirim yerine kullanıcının kendi geçmişine göre alakalı içerik).
   * Aynı bayi+ürün kombinasyonuna bir daha önerilmez (spam önleme).
   */
  @Cron('0 8 * * *') // her gün sabah 08:00
  async suggestTrainingBasedOnHistory() {
    const ninetyDaysAgo = new Date(Date.now() - 90 * 24 * 60 * 60 * 1000);
    const tickets = await this.prisma.supportTicket.findMany({
      where: { createdAt: { gte: ninetyDaysAgo }, productName: { not: null } },
      select: { dealerId: true, productName: true },
    });

    // Bayi + ürün bazında say.
    const counts = new Map<string, number>();
    for (const t of tickets) {
      const key = `${t.dealerId}::${t.productName}`;
      counts.set(key, (counts.get(key) ?? 0) + 1);
    }

    for (const [key, count] of counts.entries()) {
      if (count < 3) continue;
      const [dealerId, productName] = key.split('::');

      const alreadySuggested = await this.prisma.trainingSuggestionLog.findUnique({
        where: { dealerId_productName: { dealerId, productName } },
      });
      if (alreadySuggested) continue;

      await this.notifications.notifyUser(
        dealerId,
        'training_suggestion',
        'Size Özel Eğitim Önerisi',
        `Son 3 ayda "${productName}" ile ilgili ${count} teknik destek talebiniz oldu. Bu ürünün eğitimini incelemenizi öneririz.`,
        { productName },
      );
      await this.prisma.trainingSuggestionLog.create({ data: { dealerId, productName } });
    }
  }

  // ============================================================
  // FAZ 6: Ürün Sağlık Skoru + Versiyon Analizi + AR-GE Geri Bildirimi
  // ============================================================

  /**
   * 0-100 arası "Teknik Sağlık Skoru" — kullanıcı isteği: "skorun neden
   * düştüğü kullanıcıya açıklanmalı", bu yüzden düşüşün sebeplerini de
   * (breakdown) döndürüyoruz. Yeni tablo gerektirmiyor, mevcut kayıtlardan
   * canlı hesaplanıyor.
   */
  async getProductHealthScore(serialNumber: string) {
    const oneYearAgo = new Date(Date.now() - 365 * 24 * 60 * 60 * 1000);

    const [tickets, measurements, escalatedCount] = await Promise.all([
      this.prisma.supportTicket.findMany({
        where: { serialNumber, createdAt: { gte: oneYearAgo } },
        select: { id: true, status: true, escalationLevel: true },
      }),
      this.prisma.ticketMeasurement.findMany({ where: { serialNumber, isOutOfRange: true } }),
      this.prisma.supportTicket.count({ where: { serialNumber, escalationLevel: { gt: 0 } } }),
    ]);

    const ticketIds = tickets.map((t) => t.id);
    const sparePartCount = ticketIds.length
      ? await this.prisma.sparePartRequest.count({ where: { ticketId: { in: ticketIds } } })
      : 0;

    const deductions = [
      { reason: 'Arıza kaydı sayısı', points: Math.min(tickets.length * 5, 40) },
      { reason: 'Limit dışı ölçüm sonucu', points: Math.min(measurements.length * 8, 30) },
      { reason: 'Yedek parça değişimi', points: Math.min(sparePartCount * 3, 15) },
      { reason: 'Eskale edilmiş kayıt', points: Math.min(escalatedCount * 10, 20) },
    ].filter((d) => d.points > 0);

    const totalDeduction = deductions.reduce((sum, d) => sum + d.points, 0);
    const score = Math.max(0, Math.min(100, 100 - totalDeduction));

    let level: string;
    if (score >= 80) level = 'İyi';
    else if (score >= 60) level = 'İzlenmeli';
    else if (score >= 40) level = 'Riskli';
    else level = 'Kritik';

    return { serialNumber, score, level, deductions, ticketCount: tickets.length };
  }

  /** Şu ana kadar en az bir kaydı olan tüm ürünlerin (seri no bazında) sağlık skoru listesi. */
  async listProductHealthScores() {
    const serials = await this.prisma.supportTicket.findMany({
      where: { serialNumber: { not: null } },
      select: { serialNumber: true, productName: true, productModel: true },
      distinct: ['serialNumber'],
    });
    return Promise.all(
      serials.map(async (s) => ({
        ...(await this.getProductHealthScore(s.serialNumber!)),
        productName: s.productName,
        productModel: s.productModel,
      })),
    );
  }

  /**
   * Aynı ürünün farklı versiyonlarını (productModel alanı üzerinden)
   * karşılaştırır — versiyon bazında arıza oranı, en çok hata alan
   * versiyon, iyileşme oranı.
   */
  async getVersionAnalysis(productName: string) {
    const tickets = await this.prisma.supportTicket.findMany({
      where: { productName },
      select: { productModel: true, createdAt: true },
    });

    const byVersion = new Map<string, number>();
    for (const t of tickets) {
      const version = t.productModel ?? 'Belirtilmemiş';
      byVersion.set(version, (byVersion.get(version) ?? 0) + 1);
    }

    const versions = Array.from(byVersion.entries())
      .map(([version, count]) => ({ version, faultCount: count }))
      .sort((a, b) => b.faultCount - a.faultCount);

    const worst = versions[0];
    const best = versions[versions.length - 1];
    const improvementRate =
      worst && best && worst.faultCount > 0 && versions.length > 1
        ? Math.round(((worst.faultCount - best.faultCount) / worst.faultCount) * 100)
        : null;

    return { productName, versions, worstVersion: worst?.version, improvementRate };
  }

  /**
   * AR-GE Otomatik Geri Bildirim — aynı ürün/modelde belirli bir eşiğin
   * üzerinde ve BİRDEN FAZLA bayide kayıt oluşursa "ürün problemi olabilir"
   * uyarısı üretir. Kalıcı bir tabloya yazmaz, her çağrıda güncel veriyle
   * yeniden hesaplanır.
   */
  async getRndFeedbackAlerts() {
    const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
    const tickets = await this.prisma.supportTicket.findMany({
      where: { createdAt: { gte: thirtyDaysAgo }, productName: { not: null } },
      select: { productName: true, productModel: true, dealerId: true, location: true },
    });

    const groups = new Map<string, { count: number; dealers: Set<string>; regions: Set<string> }>();
    for (const t of tickets) {
      const key = `${t.productName}::${t.productModel ?? ''}`;
      if (!groups.has(key)) groups.set(key, { count: 0, dealers: new Set(), regions: new Set() });
      const g = groups.get(key)!;
      g.count++;
      g.dealers.add(t.dealerId);
      if (t.location) g.regions.add(t.location);
    }

    const alerts: { productName: string; productModel: string | null; ticketCount: number; dealerCount: number; regionCount: number }[] = [];
    for (const [key, g] of groups.entries()) {
      // Eşik: son 30 günde 5+ kayıt VE en az 3 farklı bayide görülmüş olmalı.
      if (g.count >= 5 && g.dealers.size >= 3) {
        const [productName, productModel] = key.split('::');
        alerts.push({
          productName,
          productModel: productModel || null,
          ticketCount: g.count,
          dealerCount: g.dealers.size,
          regionCount: g.regions.size,
        });
      }
    }

    return alerts.sort((a, b) => b.ticketCount - a.ticketCount);
  }

  // ============================================================
  // FAZ 7: Isı Haritası + Anomali Tespiti + Yedek Parça Tahmini
  // ============================================================

  /**
   * Teknik Isı Haritası (#10) — gerçek bir coğrafi harita kütüphanesi
   * eklemek (Türkiye haritası) yeni bir bağımlılık riski taşıdığı için,
   * aynı analitik değeri veren bir yoğunluk tablosu olarak sunuluyor:
   * konum (kayıttaki serbest metin konum alanı) bazında arıza/destek
   * yoğunluğu, ürün bazlı problemler, bayi bazlı destek yoğunluğu.
   */
  async getHeatMapData() {
    const tickets = await this.prisma.supportTicket.findMany({
      select: { location: true, productName: true, dealerId: true, dealer: { select: { firstName: true, lastName: true, company: true } } },
    });

    const byLocation = new Map<string, number>();
    const byProduct = new Map<string, number>();
    const byDealer = new Map<string, { count: number; name: string }>();

    for (const t of tickets) {
      if (t.location) byLocation.set(t.location, (byLocation.get(t.location) ?? 0) + 1);
      if (t.productName) byProduct.set(t.productName, (byProduct.get(t.productName) ?? 0) + 1);
      const dealerKey = t.dealerId;
      const dealerName = `${t.dealer.firstName} ${t.dealer.lastName} (${t.dealer.company})`;
      const existing = byDealer.get(dealerKey);
      byDealer.set(dealerKey, { count: (existing?.count ?? 0) + 1, name: dealerName });
    }

    const toSortedList = (map: Map<string, number>) =>
      Array.from(map.entries()).map(([label, count]) => ({ label, count })).sort((a, b) => b.count - a.count);

    return {
      byLocation: toSortedList(byLocation),
      byProduct: toSortedList(byProduct),
      byDealer: Array.from(byDealer.values()).sort((a, b) => b.count - a.count),
    };
  }

  /**
   * Anomali Tespit Sistemi (#13) — kullanıcı isteğindeki örneklerin
   * hesaplanabilir olanları: bir bayinin taleplerinin kısa sürede
   * anormal artışı, aynı seri numarasına tekrar tekrar müdahale, bir
   * ürün grubunda anormal arıza artışı. Yeni anomali tespit edilirse
   * admin'e bildirim gönderilir (aynı gün içinde tekrar bildirilmez).
   */
  @Cron('0 9 * * *') // her gün sabah 09:00
  async detectAnomalies() {
    const anomalies = await this.computeAnomalies();
    for (const a of anomalies) {
      const admins = await this.prisma.user.findMany({ where: { role: 'ADMIN' }, select: { id: true } });
      await Promise.all(
        admins.map((admin) => this.notifications.notifyUser(admin.id, 'ticket_escalated', '🔍 Anomali Tespit Edildi', a.description)),
      );
    }
  }

  async computeAnomalies() {
    const now = Date.now();
    const last7Days = new Date(now - 7 * 24 * 60 * 60 * 1000);
    const previous7Days = new Date(now - 14 * 24 * 60 * 60 * 1000);
    const last30Days = new Date(now - 30 * 24 * 60 * 60 * 1000);

    const anomalies: { type: string; description: string }[] = [];

    // 1) Bir bayinin destek taleplerinin kısa sürede anormal artışı (%200+).
    const recentTickets = await this.prisma.supportTicket.findMany({
      where: { createdAt: { gte: previous7Days } },
      select: { dealerId: true, createdAt: true, dealer: { select: { firstName: true, lastName: true, company: true } } },
    });
    const byDealerRecent = new Map<string, number>();
    const byDealerPrevious = new Map<string, number>();
    const dealerNames = new Map<string, string>();
    for (const t of recentTickets) {
      dealerNames.set(t.dealerId, `${t.dealer.firstName} ${t.dealer.lastName} (${t.dealer.company})`);
      if (t.createdAt >= last7Days) {
        byDealerRecent.set(t.dealerId, (byDealerRecent.get(t.dealerId) ?? 0) + 1);
      } else {
        byDealerPrevious.set(t.dealerId, (byDealerPrevious.get(t.dealerId) ?? 0) + 1);
      }
    }
    for (const [dealerId, recentCount] of byDealerRecent.entries()) {
      const previousCount = byDealerPrevious.get(dealerId) ?? 0;
      if (previousCount >= 1 && recentCount >= previousCount * 3) {
        anomalies.push({
          type: 'dealer_spike',
          description: `${dealerNames.get(dealerId)} bayisinin destek talepleri son 7 günde ${previousCount}'dan ${recentCount}'e yükseldi (belirgin artış).`,
        });
      }
    }

    // 2) Aynı seri numarasına tekrar tekrar müdahale (son 30 günde 3+).
    const serialTickets = await this.prisma.supportTicket.groupBy({
      by: ['serialNumber'],
      where: { createdAt: { gte: last30Days }, serialNumber: { not: null } },
      _count: { id: true },
    });
    for (const s of serialTickets) {
      if (s._count.id >= 3) {
        anomalies.push({
          type: 'repeated_intervention',
          description: `${s.serialNumber} seri numaralı ürüne son 30 günde ${s._count.id} kez müdahale edildi.`,
        });
      }
    }

    // 3) Bir ürün grubunda anormal arıza artışı (bu haftaki oran, önceki 3 haftanın ortalamasının 2 katı+).
    const eightyFourDaysAgo = new Date(now - 84 * 24 * 60 * 60 * 1000);
    const productTickets = await this.prisma.supportTicket.findMany({
      where: { createdAt: { gte: eightyFourDaysAgo }, productName: { not: null } },
      select: { productName: true, createdAt: true },
    });
    const thisWeekByProduct = new Map<string, number>();
    const priorWeeksByProduct = new Map<string, number>();
    for (const t of productTickets) {
      const key = t.productName!;
      if (t.createdAt >= last7Days) {
        thisWeekByProduct.set(key, (thisWeekByProduct.get(key) ?? 0) + 1);
      } else {
        priorWeeksByProduct.set(key, (priorWeeksByProduct.get(key) ?? 0) + 1);
      }
    }
    for (const [product, thisWeek] of thisWeekByProduct.entries()) {
      const priorAvgPerWeek = (priorWeeksByProduct.get(product) ?? 0) / 11; // ~11 hafta öncesi ortalama
      if (priorAvgPerWeek > 0 && thisWeek >= priorAvgPerWeek * 2 && thisWeek >= 3) {
        anomalies.push({
          type: 'product_spike',
          description: `"${product}" ürününde bu hafta ${thisWeek} arıza kaydı oluştu — normalin belirgin üzerinde.`,
        });
      }
    }

    return anomalies;
  }

  /**
   * Yedek Parça İhtiyaç Tahmini (#5) — geçmiş yedek parça talep verisinden
   * basit bir talep projeksiyonu yapar. ÖNEMLİ: elimizde gerçek bir stok/
   * envanter verisi olmadığı için "kritik stok riski" hesaplanamıyor —
   * bu, gelecekte bir stok modülü eklendiğinde tamamlanabilir. Şimdilik
   * dürüstçe sadece geçmiş talebe dayalı bir tahmin sunuluyor.
   */
  async getSparePartForecast() {
    const sixMonthsAgo = new Date(Date.now() - 180 * 24 * 60 * 60 * 1000);
    const requests = await this.prisma.sparePartRequest.findMany({
      where: { createdAt: { gte: sixMonthsAgo } },
      select: {
        partName: true,
        quantity: true,
        createdAt: true,
        ticket: { select: { productName: true, productModel: true, location: true, dealerId: true } },
      },
    });

    const byPart = new Map<string, { totalQty: number; requestCount: number; productName?: string | null }>();
    for (const r of requests) {
      const existing = byPart.get(r.partName) ?? { totalQty: 0, requestCount: 0, productName: r.ticket.productName };
      existing.totalQty += r.quantity;
      existing.requestCount += 1;
      byPart.set(r.partName, existing);
    }

    // 6 aylık veriden aylık ortalama, gelecek 30 gün için basit projeksiyon.
    const forecast = Array.from(byPart.entries()).map(([partName, data]) => ({
      partName,
      productName: data.productName,
      last6MonthsQuantity: data.totalQty,
      estimatedNextMonthQuantity: Math.ceil(data.totalQty / 6),
      requestCount: data.requestCount,
    }));

    return forecast.sort((a, b) => b.estimatedNextMonthQuantity - a.estimatedNextMonthQuantity);
  }

  // ============================================================
  // FAZ 8: Teknik Yetkinlik Analizi + 7 Gün Tahmin
  // ============================================================

  /**
   * Teknik Yetkinlik Analizi (#15) — kullanıcı isteğindeki kriterlerden
   * ELİMİZDEKİ VERİYLE hesaplanabilenler kullanılıyor: teknik destek
   * kaydı sayısı, ilk müdahalede çözüm oranı (eskale olmama oranı),
   * tekrar eden hatalar. "Sınav sonuçları" ve "dokümantasyon kalitesi"
   * için şu an sistemde veri kaynağı yok (eğitimlerde sınav/quiz
   * sistemi bulunmuyor) — bu kriterler dürüstçe dışarıda bırakıldı.
   */
  async getCompetencyScores() {
    const dealers = await this.prisma.user.findMany({
      where: { role: 'DEALER', status: 'ACTIVE' },
      select: { id: true, firstName: true, lastName: true, company: true },
    });

    return Promise.all(
      dealers.map(async (dealer) => {
        const tickets = await this.prisma.supportTicket.findMany({
          where: { dealerId: dealer.id },
          select: { serialNumber: true, escalationLevel: true },
        });
        if (tickets.length === 0) return null;

        const escalatedCount = tickets.filter((t) => t.escalationLevel > 0).length;
        const firstTimeResolutionRate = Math.round(((tickets.length - escalatedCount) / tickets.length) * 100);

        const serialCounts = new Map<string, number>();
        for (const t of tickets) {
          if (t.serialNumber) serialCounts.set(t.serialNumber, (serialCounts.get(t.serialNumber) ?? 0) + 1);
        }
        const repeatedFaultCount = Array.from(serialCounts.values()).filter((c) => c > 1).length;

        // Basit, açıklanabilir bir yetkinlik skoru: yüksek çözüm oranı iyi,
        // çok fazla tekrar eden hata kötü.
        const score = Math.max(0, Math.min(100, firstTimeResolutionRate - repeatedFaultCount * 5));

        return {
          dealerId: dealer.id,
          dealerName: `${dealer.firstName} ${dealer.lastName} (${dealer.company})`,
          ticketCount: tickets.length,
          firstTimeResolutionRate,
          repeatedFaultCount,
          score,
        };
      }),
    ).then((results) => results.filter((r) => r !== null).sort((a, b) => b!.score - a!.score));
  }

  /**
   * "Önümüzdeki 7 Gün" Tahmin Ekranı (#19) — geçmiş verilere dayalı basit
   * bir projeksiyon. Kullanıcı isteği gereği KESİN BİLGİ OLMADIĞI ve
   * gerekçeleri açıkça belirtiliyor.
   */
  async getSevenDayForecast() {
    const fourWeeksAgo = new Date(Date.now() - 28 * 24 * 60 * 60 * 1000);
    const [recentTickets, siteVisitAppointments, rndAlerts, sparePartForecast] = await Promise.all([
      this.prisma.supportTicket.count({ where: { createdAt: { gte: fourWeeksAgo } } }),
      this.prisma.appointment.count({ where: { type: 'ON_SITE', createdAt: { gte: fourWeeksAgo }, status: { not: 'CANCELLED' } } }),
      this.getRndFeedbackAlerts(),
      this.getSparePartForecast(),
    ]);

    const avgDailyTickets = recentTickets / 28;
    const avgDailySiteVisits = siteVisitAppointments / 28;

    return {
      expectedTicketVolume: {
        estimate: Math.round(avgDailyTickets * 7),
        basis: `Son 4 haftalık ortalama günlük ${avgDailyTickets.toFixed(1)} kayda dayanarak.`,
      },
      expectedSiteVisits: {
        estimate: Math.round(avgDailySiteVisits * 7),
        basis: `Son 4 haftalık ortalama günlük ${avgDailySiteVisits.toFixed(1)} saha ziyaretine dayanarak.`,
      },
      possibleProductIssues: rndAlerts.slice(0, 5),
      sparePartNeeds: sparePartForecast.slice(0, 5),
      disclaimer:
        'Bu tahminler geçmiş verilere dayalı basit bir projeksiyondur, KESİN BİLGİ DEĞİLDİR. Gerçek sonuçlar mevsimsellik, kampanyalar ve öngörülemeyen olaylara göre farklılık gösterebilir.',
    };
  }

  /**
   * Her 5 dakikada bir çalışır: SLA süresi dolan ama işleme alınmamış
   * kayıtları tespit edip otomatik eskalasyon yapar (kullanıcı isteği:
   * "belirlenen sürede yanıt verilmezse kayıt bir üst yetkiliye
   * aktarılabilsin"). Her eskalasyon TicketEscalation olarak kalıcı
   * kaydedilir.
   */
  @Cron('*/5 * * * *')
  async checkSlaBreaches() {
    const openTickets = await this.prisma.supportTicket.findMany({
      where: { status: { notIn: ['RESOLVED', 'CLOSED', 'ESCALATED'] } },
    });

    for (const ticket of openTickets) {
      const status = this.computeSlaStatus(ticket);
      const alreadyResponseEscalated = ticket.escalationLevel >= 1;
      const alreadyResolutionEscalated = ticket.escalationLevel >= 2;

      if (status.responseBreached && !alreadyResponseEscalated) {
        await this.escalate(ticket.id, 1, 'Yanıt süresi (SLA) aşıldı — kayıt henüz üstlenilmedi.');
      } else if (status.resolutionBreached && !alreadyResolutionEscalated) {
        await this.escalate(ticket.id, 2, 'Çözüm süresi (SLA) aşıldı.');
      }
    }
  }

  private async escalate(ticketId: string, level: number, reason: string) {
    await this.prisma.supportTicket.update({
      where: { id: ticketId },
      data: { escalationLevel: level, status: 'ESCALATED' },
    });
    await this.prisma.ticketEscalation.create({
      data: { ticketId, level, reason },
    });

    const admins = await this.prisma.user.findMany({ where: { role: 'ADMIN' }, select: { id: true } });
    await Promise.all(
      admins.map((a) =>
        this.notifications.notifyUser(a.id, 'ticket_escalated', '⚠️ Kayıt Yükseltildi (Eskalasyon)', reason, { ticketId }),
      ),
    );
  }
}
