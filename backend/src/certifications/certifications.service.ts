import { Injectable, ForbiddenException } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { PrismaService } from '../common/prisma/prisma.service';
import { StorageService } from '../common/storage/storage.service';
import { NotificationsService } from '../notifications/notifications.service';

@Injectable()
export class CertificationsService {
  constructor(
    private prisma: PrismaService,
    private storage: StorageService,
    private notifications: NotificationsService,
  ) {}

  list(userId: string) {
    return this.prisma.certification.findMany({
      where: { userId },
      orderBy: { expiresAt: 'asc' },
    });
  }

  create(userId: string, data: { brand: string; title: string; issuedAt?: string; expiresAt?: string }) {
    return this.prisma.certification.create({
      data: {
        userId,
        brand: data.brand,
        title: data.title,
        issuedAt: data.issuedAt ? new Date(data.issuedAt) : undefined,
        expiresAt: data.expiresAt ? new Date(data.expiresAt) : undefined,
      },
    });
  }

  async remove(id: string, userId: string) {
    const cert = await this.prisma.certification.findUnique({ where: { id } });
    if (!cert) return { success: true };
    if (cert.userId !== userId) throw new ForbiddenException('Sadece kendi sertifikanızı silebilirsiniz.');
    await this.prisma.certification.delete({ where: { id } });
    return { success: true };
  }

  /** Süresi 30 gün içinde dolacak sertifikalar — hatırlatma için. */
  async expiringSoon(userId: string) {
    const in30Days = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
    return this.prisma.certification.findMany({
      where: { userId, expiresAt: { lte: in30Days, gte: new Date() } },
    });
  }

  /**
   * Her gün saat 09:00'da çalışır: süresi 30 gün içinde dolacak ama daha
   * önce hiç uyarılmamış sertifikalar için bir bildirim gönderir. Önceden
   * "süresi yaklaşan sertifikalar" sorgusu vardı ama hiçbir yerde gerçek
   * bir bildirime dönüşmüyordu — bu, o eksikliğin çözümü.
   */
  @Cron(CronExpression.EVERY_DAY_AT_9AM)
  async notifyExpiringCertifications() {
    const in30Days = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
    const expiring = await this.prisma.certification.findMany({
      where: { expiresAt: { lte: in30Days, gte: new Date() }, expiryNotifiedAt: null },
    });

    for (const cert of expiring) {
      const daysLeft = Math.ceil((cert.expiresAt!.getTime() - Date.now()) / (24 * 60 * 60 * 1000));
      await this.notifications.notifyUser(
        cert.userId,
        'certification_expiring',
        'Sertifika Süresi Yaklaşıyor',
        `"${cert.brand} — ${cert.title}" sertifikanızın süresi ${daysLeft} gün içinde doluyor.`,
      );
      await this.prisma.certification.update({ where: { id: cert.id }, data: { expiryNotifiedAt: new Date() } });
    }
  }

  /** Sertifikanın fotoğrafını/taramasını (kanıt belgesi) yükler. */
  async attachDocument(certId: string, userId: string, file: Express.Multer.File) {
    const cert = await this.prisma.certification.findUnique({ where: { id: certId } });
    if (!cert) return null;
    if (cert.userId !== userId) {
      throw new ForbiddenException('Sadece kendi sertifikanıza dosya ekleyebilirsiniz.');
    }
    const key = await this.storage.upload(file.buffer, file.originalname, file.mimetype, 'certifications');
    return this.prisma.certification.update({ where: { id: certId }, data: { documentUrl: key } });
  }

  async getSignedDocumentUrl(certId: string, userId: string) {
    const cert = await this.prisma.certification.findUnique({ where: { id: certId } });
    if (!cert?.documentUrl) return null;
    if (cert.userId !== userId) {
      throw new ForbiddenException('Bu sertifikaya erişiminiz yok.');
    }
    return this.storage.getSignedUrl(cert.documentUrl);
  }
}
