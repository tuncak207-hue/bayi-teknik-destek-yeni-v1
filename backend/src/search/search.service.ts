import { Injectable } from '@nestjs/common';
import { PrismaService } from '../common/prisma/prisma.service';

@Injectable()
export class SearchService {
  constructor(private prisma: PrismaService) {}

  async search(query: string, requestingUserId?: string) {
    const q = query.trim();
    if (!q) return { documents: [], dealers: [], posts: [] };

    let blockedIds: string[] = [];
    if (requestingUserId) {
      const blocks = await this.prisma.block.findMany({
        where: { OR: [{ blockerId: requestingUserId }, { blockedId: requestingUserId }] },
      });
      blockedIds = blocks.map((b) => (b.blockerId === requestingUserId ? b.blockedId : b.blockerId));
    }

    const [documents, dealers, posts] = await Promise.all([
      this.prisma.document.findMany({
        where: {
          OR: [
            { title: { contains: q, mode: 'insensitive' } },
            { brand: { contains: q, mode: 'insensitive' } },
            { model: { contains: q, mode: 'insensitive' } },
          ],
        },
        take: 10,
      }),
      this.prisma.user.findMany({
        where: {
          role: 'DEALER',
          status: 'ACTIVE',
          id: { notIn: blockedIds },
          OR: [
            { company: { contains: q, mode: 'insensitive' } },
            { firstName: { contains: q, mode: 'insensitive' } },
            { lastName: { contains: q, mode: 'insensitive' } },
          ],
        },
        select: { id: true, firstName: true, lastName: true, company: true, avatarUrl: true },
        take: 10,
      }),
      this.prisma.communityPost.findMany({
        where: {
          OR: [
            { title: { contains: q, mode: 'insensitive' } },
            { body: { contains: q, mode: 'insensitive' } },
          ],
        },
        take: 10,
      }),
    ]);

    return { documents, dealers, posts };
  }

  /**
   * Doküman İÇERİĞİNDE (başlık/marka/model değil, gerçek metin) arama.
   * Önceden sadece başlık/marka/model aranıyordu — RAG için zaten
   * parçalanıp saklanmış olan doküman metnini burada tekrar kullanıyoruz.
   * Eşleşen parçaların ait olduğu dokümanları, sayfa numarasıyla birlikte
   * döner (kaç farklı yerde geçtiğini de sayar).
   */
  async searchDocumentContent(query: string) {
    const q = query.trim();
    if (!q) return [];

    const chunks = await this.prisma.documentChunk.findMany({
      where: { content: { contains: q, mode: 'insensitive' } },
      include: { documentVersion: { include: { document: true } } },
      take: 30,
    });

    const grouped = new Map<string, { document: any; pages: Set<number>; matchCount: number }>();
    for (const chunk of chunks) {
      const doc = chunk.documentVersion.document;
      const existing = grouped.get(doc.id);
      if (existing) {
        existing.pages.add(chunk.page);
        existing.matchCount++;
      } else {
        grouped.set(doc.id, { document: doc, pages: new Set([chunk.page]), matchCount: 1 });
      }
    }

    return Array.from(grouped.values()).map((g) => ({
      document: g.document,
      pages: Array.from(g.pages).sort((a, b) => a - b),
      matchCount: g.matchCount,
    }));
  }
}
