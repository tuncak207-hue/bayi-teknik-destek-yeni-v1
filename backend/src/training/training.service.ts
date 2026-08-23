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

  list() {
    return this.prisma.trainingContent.findMany({ orderBy: { createdAt: 'desc' } });
  }

  async getFileUrl(id: string) {
    const content = await this.prisma.trainingContent.findUnique({ where: { id } });
    if (!content) return null;
    if (content.fileUrl.startsWith('http')) return content.fileUrl;
    return this.storage.getSignedUrl(content.fileUrl);
  }

  async createWithFile(
    params: { title: string; description?: string; type: 'VIDEO' | 'DOCUMENT'; category?: string },
    file: Express.Multer.File,
  ) {
    const key = await this.storage.upload(file.buffer, file.originalname, file.mimetype, 'training');
    return this.finishCreate(params, key);
  }

  async createWithUrl(params: { title: string; description?: string; type: 'VIDEO' | 'DOCUMENT'; category?: string; url: string }) {
    return this.finishCreate(params, params.url);
  }

  private async finishCreate(
    params: { title: string; description?: string; type: 'VIDEO' | 'DOCUMENT'; category?: string },
    fileUrl: string,
  ) {
    const content = await this.prisma.trainingContent.create({
      data: {
        title: params.title,
        description: params.description,
        type: params.type,
        category: params.category,
        fileUrl,
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
