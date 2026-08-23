import { Injectable } from '@nestjs/common';
import { PrismaService } from '../common/prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';

@Injectable()
export class AnnouncementsService {
  constructor(private prisma: PrismaService, private notifications: NotificationsService) {}

  list() {
    return this.prisma.announcement.findMany({ orderBy: { createdAt: 'desc' } });
  }

  /**
   * Bayinin kendi görünümü — kaldırdığı (dismissed) duyurular listede
   * görünmez, ama gerçekten silinmez (admin ve diğer bayiler için hâlâ var).
   */
  async listForDealer(userId: string) {
    const acks = await this.prisma.announcementAcknowledgement.findMany({
      where: { userId },
      select: { announcementId: true, dismissed: true, readAt: true },
    });
    const dismissedIds = acks.filter((a) => a.dismissed).map((a) => a.announcementId);
    const readIds = new Set(acks.filter((a) => a.readAt !== null).map((a) => a.announcementId));

    const announcements = await this.prisma.announcement.findMany({
      where: { id: { notIn: dismissedIds } },
      orderBy: { createdAt: 'desc' },
    });
    return announcements.map((a) => ({ ...a, isRead: readIds.has(a.id) }));
  }

  /** Bayi duyuruyu açtığında (detaya girdiğinde) okundu olarak işaretlenir. */
  async markReadForUser(id: string, userId: string) {
    await this.prisma.announcementAcknowledgement.upsert({
      where: { announcementId_userId: { announcementId: id, userId } },
      create: { announcementId: id, userId, readAt: new Date() },
      update: { readAt: new Date() },
    });
    return { success: true };
  }

  async get(id: string) {
    return this.prisma.announcement.findUnique({ where: { id } });
  }

  /** Bayi bu duyuruyu kendi listesinden kaldırır — duyuru silinmez, sadece bu kullanıcı için gizlenir. */
  async dismissForUser(id: string, userId: string) {
    await this.prisma.announcementAcknowledgement.upsert({
      where: { announcementId_userId: { announcementId: id, userId } },
      create: { announcementId: id, userId, dismissed: true },
      update: { dismissed: true },
    });
    return { success: true };
  }

  async create(title: string, body: string, isCritical = false) {
    const announcement = await this.prisma.announcement.create({ data: { title, body, isCritical } });

    const dealers = await this.prisma.user.findMany({
      where: { role: 'DEALER', status: 'ACTIVE' },
      select: { id: true },
    });
    await Promise.all(
      dealers.map((d) =>
        this.notifications.notifyUser(
          d.id,
          'announcement',
          isCritical ? `⚠️ KRİTİK: ${title}` : title,
          body,
        ),
      ),
    );

    return announcement;
  }

  async remove(id: string) {
    await this.prisma.announcement.delete({ where: { id } });
    return { deleted: true };
  }

  /** Admin: bir yazım hatasını düzeltmek için tüm duyuruyu silip yeniden yazmaya gerek kalmasın diye. */
  async update(id: string, data: { title?: string; body?: string; isCritical?: boolean }) {
    return this.prisma.announcement.update({
      where: { id },
      data: {
        ...(data.title !== undefined && { title: data.title }),
        ...(data.body !== undefined && { body: data.body }),
        ...(data.isCritical !== undefined && { isCritical: data.isCritical }),
      },
    });
  }

  /** Bayinin henüz onaylamadığı kritik duyurular — uygulama açılışında zorunlu ekran için. */
  async listUnacknowledgedCritical(userId: string) {
    return this.prisma.announcement.findMany({
      where: {
        isCritical: true,
        acknowledgements: { none: { userId } },
      },
      orderBy: { createdAt: 'asc' },
    });
  }

  async acknowledge(announcementId: string, userId: string) {
    return this.prisma.announcementAcknowledgement.upsert({
      where: { announcementId_userId: { announcementId, userId } },
      create: { announcementId, userId },
      update: {},
    });
  }

  /** Admin: bu duyuruyu kimler okudu / kimler henüz okumadı. */
  /** Bu duyuruyu kimler okudu, kimler (kritik ise) onayladı — admin panel için. */
  async readStatus(announcementId: string) {
    const [acks, allDealers] = await Promise.all([
      this.prisma.announcementAcknowledgement.findMany({
        where: { announcementId },
        include: { user: { select: { id: true, firstName: true, lastName: true, company: true } } },
      }),
      this.prisma.user.findMany({
        where: { role: 'DEALER', status: 'ACTIVE' },
        select: { id: true, firstName: true, lastName: true, company: true },
      }),
    ]);

    // "Okundu" (readAt dolu) — kullanıcı isteği: "duyurular okunduğunda
    // admin paneline okundu bilgisi gönder." acknowledgedAt her kayıtta
    // otomatik dolduğu için (varsayılan değer) tek başına "okundu"
    // anlamına gelmiyor — geriye dönük uyumluluk için "onaylandı" listesi
    // (kritik duyuru "Anladım" akışı) olduğu gibi korunuyor.
    const read = acks.filter((a) => a.readAt !== null);
    const readIds = new Set(read.map((a) => a.userId));
    const notRead = allDealers.filter((d) => !readIds.has(d.id));

    return {
      read: read.map((a) => ({ ...a.user, readAt: a.readAt })),
      notRead,
      acknowledged: acks.map((a) => ({ ...a.user, acknowledgedAt: a.acknowledgedAt })),
      notAcknowledged: allDealers.filter((d) => !new Set(acks.map((a) => a.userId)).has(d.id)),
    };
  }
}
