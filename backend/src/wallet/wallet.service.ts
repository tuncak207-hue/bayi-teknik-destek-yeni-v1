import { Injectable, ForbiddenException, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../common/prisma/prisma.service';
import { StorageService } from '../common/storage/storage.service';

@Injectable()
export class WalletService {
  constructor(private prisma: PrismaService, private storage: StorageService) {}

  list(userId: string) {
    return this.prisma.walletDocument.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
    });
  }

  async create(userId: string, name: string, category: string, file: Express.Multer.File) {
    const key = await this.storage.upload(file.buffer, file.originalname, file.mimetype, 'wallet-documents');
    return this.prisma.walletDocument.create({
      data: { userId, name, category: category as any, fileUrl: key },
    });
  }

  private async ensureOwn(id: string, userId: string) {
    const doc = await this.prisma.walletDocument.findUnique({ where: { id } });
    if (!doc) throw new NotFoundException('Belge bulunamadı.');
    if (doc.userId !== userId) throw new ForbiddenException('Bu belgeye erişiminiz yok.');
    return doc;
  }

  async update(id: string, userId: string, name?: string, category?: string) {
    await this.ensureOwn(id, userId);
    return this.prisma.walletDocument.update({
      where: { id },
      data: {
        ...(name !== undefined && { name }),
        ...(category !== undefined && { category: category as any }),
      },
    });
  }

  async getSignedUrl(id: string, userId: string) {
    const doc = await this.ensureOwn(id, userId);
    return this.storage.getSignedUrl(doc.fileUrl);
  }

  async remove(id: string, userId: string) {
    await this.ensureOwn(id, userId);
    await this.prisma.walletDocument.delete({ where: { id } });
    return { success: true };
  }
}
