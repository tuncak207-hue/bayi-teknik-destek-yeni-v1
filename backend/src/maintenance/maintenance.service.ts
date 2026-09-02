import { Injectable, ForbiddenException, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../common/prisma/prisma.service';
import { StorageService } from '../common/storage/storage.service';

@Injectable()
export class MaintenanceService {
  constructor(private prisma: PrismaService, private storage: StorageService) {}

  /**
   * Sadece kendi kaydettiği bakım kayıtlarını listeler — bu, bayinin kendi
   * "dijital servis defteri" gibi çalışır (başka bayilerin sahalarını
   * görmesine gerek yok).
   */
  list(userId: string) {
    return this.prisma.maintenanceRecord.findMany({
      where: { createdByUserId: userId },
      orderBy: { performedAt: 'desc' },
    });
  }

  create(userId: string, data: { siteName: string; systemDescription?: string; notes: string; performedAt?: string; commissioningReportId?: string }) {
    return this.prisma.maintenanceRecord.create({
      data: {
        createdByUserId: userId,
        siteName: data.siteName,
        systemDescription: data.systemDescription,
        notes: data.notes,
        performedAt: data.performedAt ? new Date(data.performedAt) : new Date(),
        commissioningReportId: data.commissioningReportId,
      },
    });
  }

  async get(recordId: string, userId: string) {
    const record = await this.prisma.maintenanceRecord.findUnique({ where: { id: recordId } });
    if (!record) throw new NotFoundException('Bakım kaydı bulunamadı.');
    if (record.createdByUserId !== userId) throw new ForbiddenException('Bu kayda erişiminiz yok.');
    return record;
  }

  /** Bakım kaydının içeriği düzenlenebilmeli — kullanıcı isteği. */
  async update(
    recordId: string,
    userId: string,
    data: Partial<{ siteName: string; systemDescription: string; notes: string }>,
  ) {
    await this.get(recordId, userId);
    return this.prisma.maintenanceRecord.update({
      where: { id: recordId },
      data: {
        ...(data.siteName !== undefined && { siteName: data.siteName }),
        ...(data.systemDescription !== undefined && { systemDescription: data.systemDescription }),
        ...(data.notes !== undefined && { notes: data.notes }),
      },
    });
  }

  /** Müşteri imzasını (PNG görsel) yükleyip kayda ekler. */
  async attachSignature(recordId: string, userId: string, file: Express.Multer.File) {
    const record = await this.prisma.maintenanceRecord.findUnique({ where: { id: recordId } });
    if (!record) return null;
    if (record.createdByUserId !== userId) {
      throw new ForbiddenException('Sadece kendi bakım kaydınıza imza ekleyebilirsiniz.');
    }
    const key = await this.storage.upload(file.buffer, file.originalname, file.mimetype, 'signatures');
    return this.prisma.maintenanceRecord.update({ where: { id: recordId }, data: { signatureUrl: key } });
  }

  async getSignedSignatureUrl(recordId: string, userId: string) {
    const record = await this.prisma.maintenanceRecord.findUnique({ where: { id: recordId } });
    if (!record?.signatureUrl) return null;
    if (record.createdByUserId !== userId) {
      throw new ForbiddenException('Bu kayda erişiminiz yok.');
    }
    return this.storage.getSignedUrl(record.signatureUrl);
  }

  async remove(recordId: string, userId: string) {
    const record = await this.prisma.maintenanceRecord.findUnique({ where: { id: recordId } });
    if (!record) return { success: true };
    if (record.createdByUserId !== userId) {
      throw new ForbiddenException('Sadece kendi kaydınızı silebilirsiniz.');
    }
    await this.prisma.maintenanceRecord.delete({ where: { id: recordId } });
    return { success: true };
  }
}
