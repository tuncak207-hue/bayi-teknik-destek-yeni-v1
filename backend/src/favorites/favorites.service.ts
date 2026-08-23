import { Injectable } from '@nestjs/common';
import { PrismaService } from '../common/prisma/prisma.service';

@Injectable()
export class FavoritesService {
  constructor(private prisma: PrismaService) {}

  async list(userId: string) {
    const favorites = await this.prisma.favorite.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      include: {
        message: {
          select: { id: true, content: true, confidence: true, senderType: true, createdAt: true, conversationId: true },
        },
      },
    });

    // documentId'si olan favoriler için ayrıca doküman bilgisini çekiyoruz
    // (Prisma'da Favorite -> Document ilişkisi tek yönlü tanımlı değil, elle join ediyoruz).
    const documentIds = favorites.filter((f) => f.documentId).map((f) => f.documentId as string);
    const documents = documentIds.length
      ? await this.prisma.document.findMany({ where: { id: { in: documentIds } } })
      : [];
    const documentMap = new Map(documents.map((d) => [d.id, d]));

    return favorites.map((f) => ({
      id: f.id,
      createdAt: f.createdAt,
      pinned: f.pinned,
      message: f.message ?? null,
      document: f.documentId ? documentMap.get(f.documentId) ?? null : null,
    }));
  }

  /** Ana Sayfa'da her zaman görünmesi için bir favoriyi sabitler/kaldırır. */
  async togglePin(userId: string, favoriteId: string) {
    const favorite = await this.prisma.favorite.findUnique({ where: { id: favoriteId } });
    if (!favorite || favorite.userId !== userId) return { pinned: false };
    const updated = await this.prisma.favorite.update({
      where: { id: favoriteId },
      data: { pinned: !favorite.pinned },
    });
    return { pinned: updated.pinned };
  }

  /** Ana Sayfa'da gösterilecek sabitlenmiş doküman favorileri (en fazla 4). */
  async listPinned(userId: string) {
    const pinned = await this.prisma.favorite.findMany({
      where: { userId, pinned: true, documentId: { not: null } },
      orderBy: { createdAt: 'desc' },
      take: 4,
    });
    const documentIds = pinned.map((f) => f.documentId as string);
    if (documentIds.length === 0) return [];
    const documents = await this.prisma.document.findMany({ where: { id: { in: documentIds } } });
    const documentMap = new Map(documents.map((d) => [d.id, d]));
    return pinned.map((f) => ({ favoriteId: f.id, document: documentMap.get(f.documentId as string) })).filter((x) => x.document);
  }

  async toggleDocumentFavorite(userId: string, documentId: string) {
    const existing = await this.prisma.favorite.findFirst({ where: { userId, documentId } });
    if (existing) {
      await this.prisma.favorite.delete({ where: { id: existing.id } });
      return { favorited: false };
    }
    await this.prisma.favorite.create({ data: { userId, documentId } });
    return { favorited: true };
  }
}
