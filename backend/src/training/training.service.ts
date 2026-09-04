import { Injectable } from '@nestjs/common';
import { PrismaService } from '../common/prisma/prisma.service';
import { StorageService } from '../common/storage/storage.service';
import { NotificationsService } from '../notifications/notifications.service';

@Injectable()
export class TrainingService {
  constructor(
    private prisma: PrismaService,
    private storage: StorageService,
    private notifications: NotificationsService,
  ) {}

  /**
   * Kullanıcı isteği: "eğitimi tamamlamak için 1 gün verelim, geri sayaç
   * işlesin..." — bir eğitimin bitiş süresini (deadline) ve o an itibarıyla
   * durumunu (tamamlandı / devam ediyor / süresi doldu) hesaplayan ortak
   * yardımcı. Ayrı bir arka plan işi (cron) GEREKMİYOR — durum her zaman
   * isteğin geldiği anda, deadline'a göre hesaplanıyor.
   */
  private computeStatus(training: { requiresCompletion: boolean; createdAt: Date; deadlineHours: number }, completedAt: Date | null) {
    if (completedAt) return { status: 'COMPLETED', deadline: null, completedAt };
    if (!training.requiresCompletion) return { status: null, deadline: null, completedAt: null };
    const deadline = new Date(training.createdAt.getTime() + training.deadlineHours * 3600 * 1000);
    const status = new Date() >= deadline ? 'EXPIRED' : 'PENDING';
    return { status, deadline, completedAt: null };
  }

  async list(userId: string) {
    const contents = await this.prisma.trainingContent.findMany({
      orderBy: { createdAt: 'desc' },
      include: { completions: { where: { userId } } },
    });
    return contents.map((c) => {
      const myCompletion = c.completions[0] ?? null;
      const { completions, ...rest } = c;
      return { ...rest, ...this.computeStatus(c, myCompletion?.completedAt ?? null) };
    });
  }

  async getFileUrl(id: string) {
    const content = await this.prisma.trainingContent.findUnique({ where: { id } });
    if (!content) return null;
    if (content.fileUrl.startsWith('http')) return content.fileUrl;
    return this.storage.getSignedUrl(content.fileUrl);
  }

  /** Kullanıcı "Eğitimi Tamamladım" butonuna basınca çağrılır. */
  async markCompleted(trainingId: string, userId: string) {
    await this.prisma.trainingCompletion.upsert({
      where: { trainingId_userId: { trainingId, userId } },
      create: { trainingId, userId },
      update: {},
    });
    return { success: true };
  }

  /**
   * Admin panelinde "kim izledi kim izlemedi" görünümü — tüm aktif
   * bayileri, bu eğitim için tamamlama kaydıyla (varsa) birlikte döner.
   * Kaydı olmayan bayiler, deadline'a göre "PENDING" ya da "EXPIRED"
   * olarak hesaplanır.
   */
  async getCompletionsForAdmin(trainingId: string) {
    const training = await this.prisma.trainingContent.findUnique({ where: { id: trainingId } });
    if (!training) return null;
    const dealers = await this.prisma.user.findMany({
      where: { role: 'DEALER', status: 'ACTIVE' },
      select: { id: true, firstName: true, lastName: true, company: true },
    });
    const completions = await this.prisma.trainingCompletion.findMany({ where: { trainingId } });
    const completionByUser = new Map<string, Date>(completions.map((c) => [c.userId, c.completedAt]));
    const rows = dealers.map((d) => {
      const completedAt = completionByUser.get(d.id) ?? null;
      return { ...d, ...this.computeStatus(training, completedAt) };
    });
    return { training, rows };
  }

  async createWithFile(
    params: { title: string; description?: string; type: 'VIDEO' | 'DOCUMENT'; category?: string; requiresCompletion?: boolean; deadlineHours?: number },
    file: Express.Multer.File,
  ) {
    const key = await this.storage.upload(file.buffer, file.originalname, file.mimetype, 'training');
    return this.finishCreate(params, key);
  }

  async createWithUrl(params: { title: string; description?: string; type: 'VIDEO' | 'DOCUMENT'; category?: string; url: string; requiresCompletion?: boolean; deadlineHours?: number }) {
    return this.finishCreate(params, params.url);
  }

  private async finishCreate(
    params: { title: string; description?: string; type: 'VIDEO' | 'DOCUMENT'; category?: string; requiresCompletion?: boolean; deadlineHours?: number },
    fileUrl: string,
  ) {
    const content = await this.prisma.trainingContent.create({
      data: {
        title: params.title,
        description: params.description,
        type: params.type,
        category: params.category,
        fileUrl,
        requiresCompletion: params.requiresCompletion ?? false,
        deadlineHours: params.deadlineHours ?? 24,
      },
    });

    const dealers = await this.prisma.user.findMany({ where: { role: 'DEALER', status: 'ACTIVE' }, select: { id: true } });
    await Promise.all(
      dealers.map((d) =>
        this.notifications.notifyUser(
          d.id,
          'new_training_content',
          'Yeni Eğitim İçeriği',
          `"${params.title}" eklendi — Eğitim Merkezi'nde inceleyebilirsiniz.`,
        ),
      ),
    );

    return content;
  }

  async remove(id: string) {
    await this.prisma.trainingContent.delete({ where: { id } });
    return { success: true };
  }

  /** Admin, video/dosyanın kendisine dokunmadan başlık/açıklama/kategoriyi düzenler. */
  async update(id: string, data: Partial<{ title: string; description: string; category: string }>) {
    return this.prisma.trainingContent.update({ where: { id }, data });
  }
}
