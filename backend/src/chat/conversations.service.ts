import { Injectable, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../common/prisma/prisma.service';

@Injectable()
export class ConversationsService {
  constructor(private prisma: PrismaService) {}

  /** Her bayinin kendine ait, tek bir sürekli AI konuşması olabilir ya da her soru için yeni. */
  /**
   * Kullanıcı isteği: "her soru aynı konu içinde 1 kez listelensin" — artık
   * her yeni soru için ayrı bir konuşma açmak yerine, kullanıcının zaten
   * var olan TEK AI konuşması varsa onu bulup kullanıyoruz. Sadece hiç AI
   * konuşması yoksa yeni bir tane oluşturuluyor.
   */
  async createAiConversation(userId: string, title?: string) {
    const existing = await this.prisma.conversation.findFirst({
      where: { type: 'AI', participants: { some: { userId } } },
      orderBy: { createdAt: 'asc' },
    });
    if (existing) return existing;

    return this.prisma.conversation.create({
      data: {
        type: 'AI',
        title,
        participants: { create: [{ userId }] },
      },
    });
  }

  /**
   * Kullanıcı isteği: "yeni sohbet dediğimde ayrı bir kart açmalı, eski
   * sohbet eski kartının içinde, yeni sohbet yeni kartının içinde
   * kalmalı" — createAiConversation'ın aksine, mevcut olanı ARAMADAN
   * her zaman TAMAMEN YENİ, ayrı bir AI konuşması oluşturur.
   */
  async createNewAiConversation(userId: string, title?: string) {
    return this.prisma.conversation.create({
      data: {
        type: 'AI',
        title,
        participants: { create: [{ userId }] },
      },
    });
  }

  async findOrCreateDirectConversation(userId: string, otherUserId: string) {
    const blocked = await this.prisma.block.findFirst({
      where: {
        OR: [
          { blockerId: userId, blockedId: otherUserId },
          { blockerId: otherUserId, blockedId: userId },
        ],
      },
    });
    if (blocked) throw new ForbiddenException('Bu kullanıcıyla mesajlaşamazsınız.');

    const existing = await this.prisma.conversation.findFirst({
      where: {
        type: 'DIRECT',
        AND: [
          { participants: { some: { userId } } },
          { participants: { some: { userId: otherUserId } } },
        ],
      },
    });
    if (existing) {
      // Daha önce "sildiğim" (gizlediğim) bir sohbeti tekrar açıyorsam,
      // WhatsApp'ta olduğu gibi otomatik olarak listede tekrar görünür
      // hale getir.
      await this.prisma.conversationParticipant.updateMany({
        where: { conversationId: existing.id, userId },
        data: { hiddenAt: null },
      });
      return existing;
    }

    return this.prisma.conversation.create({
      data: {
        type: 'DIRECT',
        participants: { create: [{ userId }, { userId: otherUserId }] },
      },
    });
  }

  async listForUser(userId: string, includeArchived = false) {
    return this.prisma.conversation.findMany({
      where: {
        participants: {
          some: includeArchived
            ? { userId, hiddenAt: null, archivedAt: { not: null } }
            : { userId, hiddenAt: null, archivedAt: null },
        },
        // ÖNEMLİ: Kullanıcı bir bayiyi arayıp sohbet ekranını açtığında
        // (henüz hiç mesaj göndermeden), backend bir DIRECT konuşma
        // kaydı oluşturuyor — bu, hiç mesaj gönderilmediyse listede
        // "hayalet" bir konuşma olarak kalıcı görünüyordu. Artık boş
        // DIRECT konuşmalar listede gösterilmiyor (Grup/AI sohbetleri
        // etkilenmiyor).
        OR: [{ type: { not: 'DIRECT' } }, { messages: { some: {} } }],
      },
      include: {
        participants: {
          select: {
            userId: true,
            lastReadAt: true,
            hiddenAt: true,
            archivedAt: true,
            user: { select: { id: true, firstName: true, lastName: true, company: true, avatarUrl: true, role: true } },
          },
        },
        // AI konuşmalarında son 2 mesajı (kullanıcının sorusu + AI'ın
        // cevabı) birlikte göstermek için 2 alıyoruz — DIRECT/GROUP
        // sohbetlerde sadece ilk (en son) eleman kullanılıyor, zararsız.
        messages: { orderBy: { createdAt: 'desc' }, take: 2 },
        group: true,
      },
      orderBy: { updatedAt: 'desc' },
    });
  }

  /**
   * WhatsApp tarzı "sohbeti sil" — geçmişi yok etmez, sadece bu
   * kullanıcının listesinden gizler. Karşı taraf yeni mesaj gönderirse
   * (bkz. messages.service.ts) otomatik olarak tekrar görünür hale gelir.
   */
  async hideForUser(conversationId: string, userId: string) {
    await this.assertParticipant(conversationId, userId);
    await this.prisma.conversationParticipant.updateMany({
      where: { conversationId, userId },
      data: { hiddenAt: new Date() },
    });
    return { hidden: true };
  }

  /** Kullanıcı isteği: "mesajlara arşivleme ekle" — sohbeti arşive taşır. */
  async archiveForUser(conversationId: string, userId: string) {
    await this.assertParticipant(conversationId, userId);
    await this.prisma.conversationParticipant.updateMany({
      where: { conversationId, userId },
      data: { archivedAt: new Date() },
    });
    return { archived: true };
  }

  async unarchiveForUser(conversationId: string, userId: string) {
    await this.assertParticipant(conversationId, userId);
    await this.prisma.conversationParticipant.updateMany({
      where: { conversationId, userId },
      data: { archivedAt: null },
    });
    return { archived: false };
  }

  /**
   * "Genel Sohbet" — tüm bayilerin otomatik üye olduğu ortak grup
   * konuşması. Bayiler sekmesi artık doğrudan bu konuşmayı gösteriyor.
   * Kullanıcı katılımcı değilse (çok nadir bir durum, örn. eski hesap)
   * otomatik katılımcı yapılır.
   */
  async getOrJoinGeneralConversation(userId: string) {
    const conversation = await this.prisma.conversation.findFirst({
      where: { type: 'GROUP', group: { name: 'Genel Sohbet' } },
    });
    if (!conversation) return null;

    await this.prisma.conversationParticipant.upsert({
      where: { conversationId_userId: { conversationId: conversation.id, userId } },
      create: { conversationId: conversation.id, userId },
      update: {},
    });
    return conversation;
  }

  /**
   * "Gönderildi/okundu" tiklerini gösterebilmek için katılımcıların
   * kendi son okuma zamanlarını (lastReadAt) döner.
   */
  async getParticipants(conversationId: string, userId: string) {
    await this.assertParticipant(conversationId, userId);
    return this.prisma.conversationParticipant.findMany({
      where: { conversationId },
      select: { userId: true, lastReadAt: true },
    });
  }

  async assertParticipant(conversationId: string, userId: string) {
    const participant = await this.prisma.conversationParticipant.findUnique({
      where: { conversationId_userId: { conversationId, userId } },
    });
    if (!participant) throw new ForbiddenException('Bu sohbete erişiminiz yok.');
  }
}
