import { Injectable, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../common/prisma/prisma.service';
import { ConversationsService } from './conversations.service';
import { NotificationsService } from '../notifications/notifications.service';
import { TechnicalAnswer } from '../ai/ai.service';
import { StorageService } from '../common/storage/storage.service';

@Injectable()
export class MessagesService {
  constructor(
    private prisma: PrismaService,
    private conversations: ConversationsService,
    private notifications: NotificationsService,
    private storage: StorageService,
  ) {}

  async sendUserMessage(params: {
    conversationId: string;
    senderId: string;
    content: string;
    attachmentUrl?: string;
    attachmentType?: string;
    replyToId?: string;
  }) {
    await this.conversations.assertParticipant(params.conversationId, params.senderId);
    await this.assertNotChatBanned(params.senderId);
    await this.assertNotBlockedInConversation(params.conversationId, params.senderId);

    // Karşı taraf bu sohbeti önceden "sildiyse" (gizlediyse), yeni bir
    // mesaj geldiğinde WhatsApp'ta olduğu gibi otomatik olarak tekrar
    // görünür hale getiriyoruz.
    await this.prisma.conversationParticipant.updateMany({
      where: { conversationId: params.conversationId, userId: { not: params.senderId } },
      data: { hiddenAt: null },
    });

    const message = await this.prisma.message.create({
      data: {
        conversationId: params.conversationId,
        senderId: params.senderId,
        senderType: 'USER',
        content: params.content,
        attachmentUrl: params.attachmentUrl,
        attachmentType: params.attachmentType,
        replyToId: params.replyToId,
      },
    });
    await this.prisma.conversation.update({
      where: { id: params.conversationId },
      data: { updatedAt: new Date() },
    });

    // Diğer katılımcılara bildirim gönder (DIRECT/GROUP sohbetlerinde;
    // AI konuşmalarında karşı taraf olmadığı için gerek yok).
    void this.notifyOtherParticipants(params.conversationId, params.senderId, params.content);

    // Mobil tarafın soket üzerinden gelen mesajın grup mu özel mi
    // olduğunu ayırt edip doğru rozeti (Mesajlar vs Gruplar) güncelleyebilmesi
    // için sohbet tipini de mesaj nesnesine ekliyoruz.
    const conversation = await this.prisma.conversation.findUnique({
      where: { id: params.conversationId },
      select: { type: true },
    });
    return { ...message, conversationType: conversation?.type };
  }

  /**
   * Admin tarafından süreli konuşma yasağı (chatBannedUntil) verilmiş bir
   * kullanıcı, süre dolana kadar mesaj gönderemez — hesabın geri kalanı
   * (giriş yapma, doküman görüntüleme vb.) etkilenmez, sadece mesajlaşma.
   */
  private async assertNotChatBanned(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId }, select: { chatBannedUntil: true } });
    if (user?.chatBannedUntil && user.chatBannedUntil > new Date()) {
      const minutesLeft = Math.ceil((user.chatBannedUntil.getTime() - Date.now()) / 60000);
      const hoursLeft = Math.ceil(minutesLeft / 60);
      const remaining = hoursLeft >= 1 ? `${hoursLeft} saat` : `${minutesLeft} dakika`;
      throw new ForbiddenException(`Mesajlaşma yetkiniz geçici olarak kısıtlandı. Kalan süre: ${remaining}.`);
    }
  }

  /**
   * DIRECT bir sohbette karşı taraf, gönderen kişiyi (ya da gönderen
   * karşı tarafı) engellemişse mesaj gönderilemez. Önceden bu kontrol
   * sadece YENİ bir sohbet başlatılırken yapılıyordu — zaten var olan bir
   * sohbette, biri diğerini engellese bile mesajlaşmaya devam edebiliyordu.
   * GROUP sohbetlerinde bu kontrol uygulanmaz (grup, iki kişi arası özel
   * bir ilişki değildir).
   */
  private async assertNotBlockedInConversation(conversationId: string, senderId: string) {
    const conversation = await this.prisma.conversation.findUnique({
      where: { id: conversationId },
      include: { participants: true },
    });
    if (!conversation || conversation.type !== 'DIRECT') return;

    const otherParticipant = conversation.participants.find((p) => p.userId !== senderId);
    if (!otherParticipant) return;

    const blocked = await this.prisma.block.findFirst({
      where: {
        OR: [
          { blockerId: senderId, blockedId: otherParticipant.userId },
          { blockerId: otherParticipant.userId, blockedId: senderId },
        ],
      },
    });
    if (blocked) throw new ForbiddenException('Bu kullanıcıyla mesajlaşamazsınız.');
  }

  private async notifyOtherParticipants(conversationId: string, senderId: string, content: string) {
    const conversation = await this.prisma.conversation.findUnique({
      where: { id: conversationId },
      include: {
        participants: { include: { user: { select: { id: true, firstName: true, lastName: true, role: true } } } },
      },
    });
    if (!conversation || conversation.type === 'AI') return;

    const sender = conversation.participants.find((p) => p.userId === senderId)?.user;
    const senderName = sender ? `${sender.firstName} ${sender.lastName}` : 'Bir bayi';
    const isGroup = conversation.type === 'GROUP';

    const others = conversation.participants.filter((p) => p.userId !== senderId);
    await Promise.all(
      others.map(async (p) => {
        // Satış danışmanına/danışmanından gelen mesajlar, "Mesajlar" ile
        // karışmaması için ayrı bir bildirim türü kullanır — Ana Sayfa'da
        // "Satış Danışmanına Sor" kartının kendi rozeti olabilsin diye.
        let type: 'new_message' | 'group_message' | 'new_sales_message' = isGroup ? 'group_message' : 'new_message';
        if (!isGroup && (p.user.role === 'SALES' || sender?.role === 'SALES')) {
          type = 'new_sales_message';
        }
        await this.notifications.notifyUser(
          p.userId,
          type,
          isGroup ? `${conversation.title ?? 'Grup'}` : senderName,
          content.length > 80 ? `${content.slice(0, 80)}...` : content,
          { conversationId },
        );
      }),
    );
  }

  /** AI cevabını mesaj olarak kaydeder, kaynak (citation) satırlarıyla birlikte. */
  async saveAiAnswer(conversationId: string, answer: TechnicalAnswer) {
    const message = await this.prisma.message.create({
      data: {
        conversationId,
        senderType: 'AI',
        content: answer.answerMarkdown,
        confidence: answer.confidence,
        // Kullanıcı isteği: "doğrulama sürekli kalmalı" — bu mesajın
        // hangi Teknik Hafıza kaydına karşılık geldiğini kalıcı olarak
        // saklıyoruz (hem hafızadan gelen hem yeni oluşturulan cevaplar
        // için — answer.memoryId ikisinde de dolu geliyor).
        technicalMemoryId: answer.memoryId,
        citations: {
          create: answer.citations.map((c) => ({
            documentChunkId: c.chunkId,
            page: c.page,
          })),
        },
      },
      include: {
        citations: { include: { documentChunk: { include: { documentVersion: { include: { document: true } } } } } },
      },
    });
    await this.prisma.conversation.update({
      where: { id: conversationId },
      data: { updatedAt: new Date() },
    });
    return message;
  }

  async listMessages(conversationId: string, userId: string, cursor?: string) {
    await this.conversations.assertParticipant(conversationId, userId);
    const messages = await this.prisma.message.findMany({
      where: {
        conversationId,
        // "Benim için gizle" ile kaldırılmış mesajlar bu kullanıcıya
        // hiç gösterilmez.
        hiddenFor: { none: { userId } },
      },
      include: {
        citations: {
          include: { documentChunk: { include: { documentVersion: { include: { document: true } } } } },
        },
        sender: { select: { id: true, firstName: true, lastName: true, avatarUrl: true } },
        // Yanıtlanan mesajın içeriğini/gönderenini de getiriyoruz — mobil
        // tarafta "alıntı" (quoted) önizlemesi gösterebilmek için.
        replyTo: { include: { sender: { select: { id: true, firstName: true, lastName: true } } } },
        reactions: { select: { id: true, emoji: true, userId: true } },
      },
      orderBy: { createdAt: 'desc' },
      take: 30,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
    });

    // Kullanıcı isteği: "doğrulama sürekli kalmalı" — technicalMemoryId'si
    // olan mesajlar için, ilgili hafıza kaydının GERÇEKTEN doğrulanmış
    // olup olmadığını (verifiedByEngineerId dolu mu) tek bir ek sorguyla
    // çekip her mesaja isVerified/memoryId olarak ekliyoruz.
    const memoryIds = messages.map((m) => m.technicalMemoryId).filter((id): id is string => !!id);
    const verifiedMap = new Map<string, boolean>();
    if (memoryIds.length > 0) {
      const memories = await this.prisma.technicalAnswerMemory.findMany({
        where: { id: { in: memoryIds } },
        select: { id: true, verifiedByEngineerId: true },
      });
      memories.forEach((m) => verifiedMap.set(m.id, !!m.verifiedByEngineerId));
    }

    return messages.map((m) => ({
      ...m,
      memoryId: m.technicalMemoryId,
      memoryIsVerified: m.technicalMemoryId ? verifiedMap.get(m.technicalMemoryId) ?? false : false,
    }));
  }

  /** Bir sohbet içinde metin araması — tüm geçmişte (sayfalama sınırı olmadan) arar. */
  async searchMessages(conversationId: string, userId: string, query: string) {
    await this.conversations.assertParticipant(conversationId, userId);
    if (!query?.trim()) return [];
    return this.prisma.message.findMany({
      where: { conversationId, content: { contains: query, mode: 'insensitive' } },
      include: { sender: { select: { id: true, firstName: true, lastName: true } } },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });
  }

  /**
   * Bir mesaja emoji tepkisi ekler/değiştirir (kişi başı tek tepki).
   * Aynı emoji ile tekrar çağrılırsa tepki kaldırılır (toggle davranışı).
   */
  async toggleReaction(userId: string, messageId: string, emoji: string) {
    const message = await this.prisma.message.findUnique({ where: { id: messageId }, select: { conversationId: true } });
    if (!message) return { reacted: false };
    await this.conversations.assertParticipant(message.conversationId, userId);
    const existing = await this.prisma.messageReaction.findUnique({
      where: { messageId_userId: { messageId, userId } },
    });
    if (existing && existing.emoji === emoji) {
      await this.prisma.messageReaction.delete({ where: { id: existing.id } });
      return { reacted: false };
    }
    await this.prisma.messageReaction.upsert({
      where: { messageId_userId: { messageId, userId } },
      create: { messageId, userId, emoji },
      update: { emoji },
    });
    return { reacted: true, emoji };
  }

  async toggleFavorite(userId: string, messageId: string) {
    const message = await this.prisma.message.findUnique({ where: { id: messageId }, select: { conversationId: true } });
    if (!message) return { favorited: false };
    await this.conversations.assertParticipant(message.conversationId, userId);
    const existing = await this.prisma.favorite.findFirst({ where: { userId, messageId } });
    if (existing) {
      await this.prisma.favorite.delete({ where: { id: existing.id } });
      return { favorited: false };
    }
    await this.prisma.favorite.create({ data: { userId, messageId } });
    return { favorited: true };
  }

  /** AI cevabına bayinin verdiği 👍/👎 geri bildirimi kaydeder. */
  async setFeedback(userId: string, messageId: string, feedback: 'UP' | 'DOWN' | null) {
    const message = await this.prisma.message.findUnique({ where: { id: messageId } });
    if (!message) return null;
    await this.conversations.assertParticipant(message.conversationId, userId);
    return this.prisma.message.update({ where: { id: messageId }, data: { feedback } });
  }

  /** Kullanıcı kendi gönderdiği bir mesajı silebilir (başkasının mesajını silemez). */
  // Mesajlar gönderildikten sonra bu süre içinde düzenlenebilir/silinebilir
  // — WhatsApp/Slack gibi uygulamalardaki "kısa süreli geri alma" mantığı.
  private static readonly EDIT_WINDOW_MINUTES = 15;

  private assertWithinEditWindow(createdAt: Date) {
    const minutesPassed = (Date.now() - createdAt.getTime()) / 60000;
    if (minutesPassed > MessagesService.EDIT_WINDOW_MINUTES) {
      throw new ForbiddenException(
        `Mesajlar gönderildikten sonra sadece ${MessagesService.EDIT_WINDOW_MINUTES} dakika içinde düzenlenebilir/silinebilir.`,
      );
    }
  }

  async editOwnMessage(userId: string, messageId: string, newContent: string) {
    const message = await this.prisma.message.findUnique({ where: { id: messageId } });
    if (!message) return { success: true };
    if (message.senderId !== userId) {
      throw new ForbiddenException('Sadece kendi mesajınızı düzenleyebilirsiniz.');
    }
    this.assertWithinEditWindow(message.createdAt);
    return this.prisma.message.update({
      where: { id: messageId },
      data: { content: newContent, editedAt: new Date() },
    });
  }

  async deleteOwnMessage(userId: string, messageId: string) {
    const message = await this.prisma.message.findUnique({ where: { id: messageId } });
    if (!message) return { success: true };
    if (message.senderId !== userId) {
      throw new ForbiddenException('Sadece kendi mesajınızı silebilirsiniz.');
    }
    // ÖNEMLİ: Kullanıcı isteği üzerine — düzenleme zaman sınırlı kalıyor,
    // ama SİLME işleminden zaman sınırı kaldırıldı. Bir mesajı silmek
    // kullanıcının her zaman sahip olması gereken bir hak; düzenlemek
    // (içeriği değiştirmek) daha hassas olduğu için o sınırlı kalıyor.
    await this.prisma.message.delete({ where: { id: messageId } });
    return { success: true };
  }

  /**
   * Karşı tarafın gönderdiği bir mesajı "benim için sil" yapar — mesaj
   * karşı tarafta ve veritabanında silinmez, sadece bu kullanıcının
   * görünümünden kalıcı olarak gizlenir. Kullanıcı isteği: "gelen
   * mesajları... silebiliyor olmam gerekirken silemiyorum."
   */
  async hideMessageForMe(userId: string, messageId: string) {
    const message = await this.prisma.message.findUnique({ where: { id: messageId }, select: { conversationId: true } });
    if (!message) return { success: true };
    await this.conversations.assertParticipant(message.conversationId, userId);
    await this.prisma.messageHiddenFor.upsert({
      where: { messageId_userId: { messageId, userId } },
      create: { messageId, userId },
      update: {},
    });
    return { success: true };
  }

  async getAttachmentSignedUrl(userId: string, key: string) {
    if (!key?.trim()) throw new ForbiddenException('Geçersiz ek dosya anahtarı.');
    const message = await this.prisma.message.findFirst({
      where: {
        attachmentUrl: key,
        conversation: { participants: { some: { userId } } },
      },
      select: { attachmentUrl: true },
    });
    if (!message?.attachmentUrl) throw new ForbiddenException('Bu eke erişim izniniz yok.');
    return this.storage.getSignedUrl(message.attachmentUrl);
  }

  // ---- Admin moderasyon metodları ----

  /** Admin: tüm DIRECT/GROUP sohbetlerini (AI hariç), katılımcı ve son mesaj bilgisiyle listeler. */
  async adminListConversations() {
    return this.prisma.conversation.findMany({
      where: { type: { in: ['DIRECT', 'GROUP'] } },
      include: {
        participants: { include: { user: { select: { id: true, firstName: true, lastName: true, company: true } } } },
        messages: { orderBy: { createdAt: 'desc' }, take: 1 },
        _count: { select: { messages: true } },
      },
      orderBy: { updatedAt: 'desc' },
    });
  }

  /** Admin: bir sohbetin tüm mesaj geçmişini (katılımcı sınırlaması olmadan) görür. */
  async adminListMessages(conversationId: string) {
    return this.prisma.message.findMany({
      where: { conversationId },
      include: { sender: { select: { id: true, firstName: true, lastName: true, company: true } } },
      orderBy: { createdAt: 'asc' },
    });
  }

  /** Admin: tek bir mesajı siler (uygunsuz içerik için). */
  async adminDeleteMessage(messageId: string) {
    await this.prisma.message.delete({ where: { id: messageId } });
    return { success: true };
  }

  /** Admin: bir sohbeti (tüm mesajlarıyla birlikte) kalıcı siler. */
  async adminDeleteConversation(conversationId: string) {
    await this.prisma.message.deleteMany({ where: { conversationId } });
    await this.prisma.conversationParticipant.deleteMany({ where: { conversationId } });
    await this.prisma.conversation.delete({ where: { id: conversationId } });
    return { success: true };
  }
}
