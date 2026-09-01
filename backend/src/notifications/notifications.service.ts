import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { PrismaService } from '../common/prisma/prisma.service';
import { ChatGateway } from '../chat/gateway/chat.gateway';

export type NotificationType =
  | 'new_message'
  | 'group_message'
  | 'reply'
  | 'announcement'
  | 'account_approved'
  | 'new_document'
  | 'appointment_requested'
  | 'appointment_status_changed'
  | 'appointment_revised'
  | 'appointment_removed'
  | 'chat_banned'
  | 'new_training_content'
  | 'certification_expiring'
  | 'new_sales_message'
  | 'emergency_ticket'
  | 'ticket_assigned'
  | 'ticket_escalated'
  | 'sla_warning'
  | 'training_suggestion'
  | 'ticket_created'
  | 'ticket_status_changed'
  | 'quote_status_changed';

@Injectable()
export class NotificationsService implements OnModuleInit {
  private readonly logger = new Logger(NotificationsService.name);
  private admin: any;

  constructor(private prisma: PrismaService, private chatGateway: ChatGateway) {}

  onModuleInit() {
    const config = process.env.FIREBASE_CONFIG;
    if (!config) {
      this.logger.warn('FIREBASE_CONFIG tanımlı değil; push bildirimleri devre dışı (sadece DB kaydı yapılacak).');
      return;
    }
    // Lazy require: firebase-admin ağır bir paket, sadece config varsa yüklensin.
    const firebaseAdmin = require('firebase-admin');
    if (!firebaseAdmin.apps.length) {
      firebaseAdmin.initializeApp({
        credential: firebaseAdmin.credential.cert(JSON.parse(config)),
      });
    }
    this.admin = firebaseAdmin;
  }

  async notifyUser(userId: string, type: NotificationType, title: string, body: string, data?: Record<string, string>) {
    const notification = await this.prisma.notification.create({
      data: { userId, type, title, body, data },
    });

    // ÖNEMLİ: Bu, Firebase (FIREBASE_CONFIG) yapılandırılmış olsun ya da
    // olmasın HER ZAMAN çalışır — uygulama açıkken (ön planda) anlık
    // bildirim + ses için birincil kanal budur. Önceden bildirimler
    // SADECE Firebase push'a bağlıydı; FIREBASE_CONFIG tanımlı değilse
    // (çoğu geliştirme ortamında olduğu gibi) hiçbir anlık sinyal
    // gitmiyordu — sadece veritabanına yazılıyordu.
    this.chatGateway.emitNotification(userId, notification);

    if (!this.admin) return;

    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user?.fcmTokens?.length || !user.notificationsEnabled) return;

    // Bildirim tercihleri: kullanıcı bu türü kapatmışsa push gönderme
    // (uygulama içi kayıt zaten yukarıda oluşturuldu, sadece push atlanıyor).
    const preferences = (user.notificationPreferences as Record<string, boolean>) || {};
    if (preferences[type] === false) return;

    // Sessiz saatler: şu an o aralıktaysa push'u atla.
    if (user.quietHoursEnabled && user.quietHoursStart && user.quietHoursEnd) {
      if (this.isWithinQuietHours(user.quietHoursStart, user.quietHoursEnd)) return;
    }

    try {
      await this.admin.messaging().sendEachForMulticast({
        tokens: user.fcmTokens,
        notification: { title, body },
        // 'type' alanını her zaman FCM veri paketine dahil ediyoruz —
        // mobil taraf bildirime dokunulduğunda hangi ekrana gideceğini
        // bununla belirliyor (derin bağlantı).
        data: { ...data, type },
      });
    } catch (e: any) {
      this.logger.error(`FCM gönderim hatası: ${e.message}`);
    }
  }

  /**
   * "22:00"-"07:00" gibi gece yarısını aşan aralıkları da doğru
   * hesaplayan basit bir saat-aralığı kontrolü.
   */
  private isWithinQuietHours(start: string, end: string): boolean {
    const now = new Date();
    const nowMinutes = now.getHours() * 60 + now.getMinutes();
    const [startH, startM] = start.split(':').map(Number);
    const [endH, endM] = end.split(':').map(Number);
    const startMinutes = startH * 60 + startM;
    const endMinutes = endH * 60 + endM;

    if (startMinutes <= endMinutes) {
      // Normal aralık, örn. 09:00-17:00
      return nowMinutes >= startMinutes && nowMinutes < endMinutes;
    }
    // Gece yarısını aşan aralık, örn. 22:00-07:00
    return nowMinutes >= startMinutes || nowMinutes < endMinutes;
  }

  async registerToken(userId: string, token: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    const tokens = new Set(user?.fcmTokens ?? []);
    tokens.add(token);
    await this.prisma.user.update({ where: { id: userId }, data: { fcmTokens: [...tokens] } });
    return { registered: true };
  }

  /**
   * Çıkış yapıldığında çağrılır — önceden bu hiç yapılmıyordu, aynı
   * cihazda hesap değiştirilirse eski hesap da bildirim almaya devam
   * edebiliyordu. Token'ı kullanıcının listesinden kaldırır.
   */
  async unregisterToken(userId: string, token: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    const tokens = (user?.fcmTokens ?? []).filter((t) => t !== token);
    await this.prisma.user.update({ where: { id: userId }, data: { fcmTokens: tokens } });
    return { unregistered: true };
  }

  /** Bildirimler ekranındaki "Tümünü okundu işaretle" için. */
  async markAllRead(userId: string) {
    await this.prisma.notification.updateMany({ where: { userId, readAt: null }, data: { readAt: new Date() } });
    return { success: true };
  }

  listForUser(userId: string) {
    return this.prisma.notification.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });
  }

  async markRead(userId: string, id: string) {
    return this.prisma.notification.updateMany({
      where: { id, userId },
      data: { readAt: new Date() },
    });
  }

  /** Kullanıcı tek bir bildirimi siler. */
  async remove(userId: string, id: string) {
    await this.prisma.notification.deleteMany({ where: { id, userId } });
    return { success: true };
  }

  /** Kullanıcı tüm bildirimlerini tek seferde temizler. */
  async removeAll(userId: string) {
    await this.prisma.notification.deleteMany({ where: { userId } });
    return { success: true };
  }

  /**
   * Ana Sayfa'daki kartların üzerinde gösterilecek kategori bazlı
   * okunmamış sayıları — "Mesajlar", "Bayilere Sor", "Gruplar" kartlarının
   * her biri kendi bildirim türüne göre ayrı ayrı rozet gösterebilsin diye.
   */
  async unreadCountsByCategory(userId: string) {
    const [messages, community, groups, appointments, training, certification, announcements, salesConsultant, supportTickets, quotes] = await Promise.all([
      this.prisma.notification.count({ where: { userId, readAt: null, type: 'new_message' } }),
      this.prisma.notification.count({ where: { userId, readAt: null, type: 'reply' } }),
      this.prisma.notification.count({ where: { userId, readAt: null, type: 'group_message' } }),
      this.prisma.notification.count({
        where: {
          userId,
          readAt: null,
          type: { in: ['appointment_requested', 'appointment_status_changed', 'appointment_revised', 'appointment_removed'] },
        },
      }),
      this.prisma.notification.count({ where: { userId, readAt: null, type: 'new_training_content' } }),
      this.prisma.notification.count({ where: { userId, readAt: null, type: 'certification_expiring' } }),
      this.prisma.notification.count({ where: { userId, readAt: null, type: 'announcement' } }),
      this.prisma.notification.count({ where: { userId, readAt: null, type: 'new_sales_message' } }),
      this.prisma.notification.count({
        where: {
          userId,
          readAt: null,
          type: { in: ['ticket_created', 'ticket_status_changed', 'ticket_assigned', 'ticket_escalated', 'emergency_ticket', 'training_suggestion'] },
        },
      }),
      // ÖNEMLİ DÜZELTME: "teklif durumu değişince hiçbir yerde rozet
      // çıkmıyor" — bu kategori hiç yoktu, Teklif Al kartı hiçbir zaman
      // rozet gösteremiyordu.
      this.prisma.notification.count({ where: { userId, readAt: null, type: 'quote_status_changed' } }),
    ]);
    return { messages, community, groups, appointments, training, certification, announcements, salesConsultant, supportTickets, quotes };
  }

  async unreadCount(userId: string) {
    const count = await this.prisma.notification.count({ where: { userId, readAt: null } });
    return { count };
  }

  /** Sadece mesaj bildirimlerinin (new_message/group_message) okunmamış sayısı — Mesajlar sekmesindeki rozet için. */
  async unreadMessageCount(userId: string) {
    const count = await this.prisma.notification.count({
      where: { userId, readAt: null, type: { in: ['new_message', 'group_message'] } },
    });
    return { count };
  }

  /**
   * Hangi sohbetlerde okunmamış mesaj bildirimi var — Mesajlar listesindeki
   * her satırın kendi rozeti için. `data` alanı JSON olduğundan, önce tüm
   * okunmamış mesaj bildirimlerini çekip conversationId'lerini JS
   * tarafında ayıklıyoruz (Prisma'nın JSON filtreleme sözdizimi veritabanı
   * sağlayıcısına göre değişkenlik gösterebildiği için bu daha güvenilir).
   */
  async unreadConversationIds(userId: string) {
    const notifications = await this.prisma.notification.findMany({
      where: { userId, readAt: null, type: { in: ['new_message', 'group_message'] } },
      select: { data: true },
    });
    const ids = new Set<string>();
    for (const n of notifications) {
      const conversationId = (n.data as any)?.conversationId;
      if (conversationId) ids.add(conversationId);
    }
    return { conversationIds: Array.from(ids) };
  }

  /** Bir sohbet açıldığında, o sohbete ait okunmamış mesaj bildirimlerini okundu işaretler. */
  /** Belirli bir türdeki (örn. 'announcement') tüm okunmamış bildirimleri okundu işaretler. */
  async markAllOfTypeRead(userId: string, type: NotificationType) {
    await this.prisma.notification.updateMany({
      where: { userId, readAt: null, type },
      data: { readAt: new Date() },
    });
    return { success: true };
  }

  /**
   * Ana Sayfa kartlarındaki kategorilerle birebir eşleşen, kategori adına
   * göre ilgili tüm bildirim türlerini okundu işaretleyen tek bir uç nokta
   * — her ekranın kendi türünü elle bilmesine gerek kalmasın diye.
   */
  async markCategoryRead(userId: string, category: string) {
    const typeMap: Record<string, NotificationType[]> = {
      community: ['reply'],
      appointments: ['appointment_requested', 'appointment_status_changed', 'appointment_revised', 'appointment_removed'],
      training: ['new_training_content'],
      certification: ['certification_expiring'],
      announcements: ['announcement'],
      support_tickets: ['ticket_created', 'ticket_status_changed', 'ticket_assigned', 'ticket_escalated', 'emergency_ticket', 'training_suggestion'],
    };
    const types = typeMap[category];
    if (!types) return { success: false };
    await this.prisma.notification.updateMany({
      where: { userId, readAt: null, type: { in: types } },
      data: { readAt: new Date() },
    });
    return { success: true };
  }

  async markConversationRead(userId: string, conversationId: string) {
    const unread = await this.prisma.notification.findMany({
      where: { userId, readAt: null, type: { in: ['new_message', 'group_message', 'new_sales_message'] } },
      select: { id: true, data: true },
    });
    const idsToMark = unread.filter((n) => (n.data as any)?.conversationId === conversationId).map((n) => n.id);
    if (idsToMark.length > 0) {
      await this.prisma.notification.updateMany({ where: { id: { in: idsToMark } }, data: { readAt: new Date() } });
    }

    // ÖNEMLİ: Önceden sadece bildirim kaydı "okundu" işaretleniyordu —
    // konuşmanın kendisinde KİMİN NE ZAMAN okuduğu hiç tutulmuyordu, bu
    // yüzden "gönderildi/okundu" tikleri hiç gösterilemiyordu. Artık
    // katılımcının kendi "son okuma zamanı" da güncelleniyor.
    await this.prisma.conversationParticipant.updateMany({
      where: { conversationId, userId },
      data: { lastReadAt: new Date() },
    });

    return { marked: idsToMark.length };
  }
}
