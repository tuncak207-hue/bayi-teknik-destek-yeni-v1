import { Injectable } from '@nestjs/common';
import { PrismaService } from '../common/prisma/prisma.service';

@Injectable()
export class StatsService {
  constructor(private prisma: PrismaService) {}

  /**
   * Admin dashboard'u — önceden sadece 4 sayısal kart vardı (bayi, doküman,
   * bugünkü AI sorusu, aktif sohbet). Şimdi uygulamanın TÜM modüllerine
   * (bayiler, dokümanlar, mesajlaşma, randevular, topluluk, duyurular,
   * moderasyon) dair kapsamlı bir özet + son aktivite akışı döndürüyor.
   */
  async dashboard() {
    const startOfToday = new Date();
    startOfToday.setHours(0, 0, 0, 0);
    const startOfWeek = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
    const startOfMonth = new Date();
    startOfMonth.setDate(1);
    startOfMonth.setHours(0, 0, 0, 0);
    const last24h = new Date(Date.now() - 24 * 60 * 60 * 1000);
    const now = new Date();

    // ÖNEMLİ: Önceden bu 19 sorgu TEK BİR Promise.all içinde, hepsi aynı
    // anda çalıştırılıyordu — Supabase bağlantı havuzunun izin verdiği
    // maksimum eş zamanlı bağlantı sayısını (15) aşıp
    // "max clients reached" hatasına yol açıyordu (Genel Bakış'ta hiç
    // veri gözükmemesinin kök sebebi buydu). Artık 3 küçük GRUBA
    // bölünüp SIRAYLA çalıştırılıyor — aynı anda en fazla ~7 bağlantı
    // açılıyor, havuzu asla zorlamıyor.
    const [dealersActive, dealersPending, dealersSuspended, newDealersThisWeek, documentsCount, documentsProcessing, documentsError] =
      await Promise.all([
        this.prisma.user.count({ where: { role: 'DEALER', status: 'ACTIVE' } }),
        this.prisma.user.count({ where: { role: 'DEALER', status: 'PENDING' } }),
        this.prisma.user.count({ where: { role: 'DEALER', status: 'SUSPENDED' } }),
        this.prisma.user.count({ where: { role: 'DEALER', createdAt: { gte: startOfWeek } } }),
        this.prisma.document.count(),
        this.prisma.document.count({ where: { status: 'PROCESSING' } }),
        this.prisma.document.count({ where: { status: 'ERROR' } }),
      ]);

    const [
      topFavoritedDocuments,
      aiQuestionsToday,
      aiQuestionsThisWeek,
      activeConversations,
      totalMessagesThisWeek,
      directConversationsCount,
      groupConversationsCount,
    ] = await Promise.all([
      this.getTopFavoritedDocuments(),
      this.prisma.message.count({
        where: { senderType: 'USER', conversation: { type: 'AI' }, createdAt: { gte: startOfToday } },
      }),
      this.prisma.message.count({
        where: { senderType: 'USER', conversation: { type: 'AI' }, createdAt: { gte: startOfWeek } },
      }),
      this.prisma.conversation.count({ where: { updatedAt: { gte: last24h } } }),
      this.prisma.message.count({ where: { createdAt: { gte: startOfWeek } } }),
      this.prisma.conversation.count({ where: { type: 'DIRECT' } }),
      this.prisma.conversation.count({ where: { type: 'GROUP' } }),
    ]);

    const [
      activeChatBans,
      appointmentsPending,
      appointmentsConfirmedUpcoming,
      appointmentsCompletedThisMonth,
      communityPostsCount,
      communityPostsThisWeek,
      communityCommentsCount,
    ] = await Promise.all([
      this.prisma.user.count({ where: { chatBannedUntil: { gt: now } } }),
      this.prisma.appointment.count({ where: { status: 'PENDING' } }),
      this.prisma.appointment.count({ where: { status: 'CONFIRMED', preferredStart: { gte: now } } }),
      this.prisma.appointment.count({ where: { status: 'COMPLETED', updatedAt: { gte: startOfMonth } } }),
      this.prisma.communityPost.count(),
      this.prisma.communityPost.count({ where: { createdAt: { gte: startOfWeek } } }),
      this.prisma.communityComment.count(),
    ]);

    const [
      announcementsCount,
      criticalAnnouncementsUnacknowledged,
      recentDealers,
      recentDocuments,
      recentAppointments,
      recentPosts,
    ] = await Promise.all([
      this.prisma.announcement.count(),
      this.prisma.announcement.count({
        where: {
          isCritical: true,
          NOT: { acknowledgements: { some: {} } }, // en az bir onay bile almamışsa "tam onaylanmamış" say
        },
      }),

      this.prisma.user.findMany({
        where: { role: 'DEALER' },
        orderBy: { createdAt: 'desc' },
        take: 5,
        select: { id: true, company: true, firstName: true, lastName: true, status: true, createdAt: true },
      }),
      this.prisma.document.findMany({
        orderBy: { createdAt: 'desc' },
        take: 5,
        select: { id: true, title: true, brand: true, model: true, status: true, createdAt: true },
      }),
      this.prisma.appointment.findMany({
        orderBy: { createdAt: 'desc' },
        take: 5,
        select: {
          id: true,
          subject: true,
          status: true,
          createdAt: true,
          dealer: { select: { company: true } },
        },
      }),
      this.prisma.communityPost.findMany({
        orderBy: { createdAt: 'desc' },
        take: 5,
        select: { id: true, title: true, createdAt: true, author: { select: { company: true } } },
      }),
    ]);

    // Son aktiviteleri tek bir zaman çizelgesinde birleştirip en yeniden eskiye sırala.
    const activity = [
      ...recentDealers.map((d) => ({
        type: 'dealer' as const,
        label: `${d.company} kaydoldu`,
        detail: d.status === 'PENDING' ? 'Onay bekliyor' : d.status,
        createdAt: d.createdAt,
        id: d.id,
      })),
      ...recentDocuments.map((d) => ({
        type: 'document' as const,
        label: `Doküman yüklendi: ${d.title}`,
        detail: `${d.brand} / ${d.model}`,
        createdAt: d.createdAt,
        id: d.id,
      })),
      ...recentAppointments.map((a) => ({
        type: 'appointment' as const,
        label: `Randevu talebi: ${a.subject}`,
        detail: a.dealer?.company ?? '',
        createdAt: a.createdAt,
        id: a.id,
      })),
      ...recentPosts.map((p) => ({
        type: 'community' as const,
        label: `Yeni gönderi: ${p.title}`,
        detail: p.author?.company ?? '',
        createdAt: p.createdAt,
        id: p.id,
      })),
    ]
      .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime())
      .slice(0, 10);

    return {
      dealers: {
        active: dealersActive,
        pending: dealersPending,
        suspended: dealersSuspended,
        newThisWeek: newDealersThisWeek,
      },
      documents: {
        total: documentsCount,
        processing: documentsProcessing,
        error: documentsError,
        topFavorited: topFavoritedDocuments,
      },
      messaging: {
        aiQuestionsToday,
        aiQuestionsThisWeek,
        activeConversations,
        totalMessagesThisWeek,
        directConversations: directConversationsCount,
        groupConversations: groupConversationsCount,
        activeChatBans,
      },
      appointments: {
        pending: appointmentsPending,
        confirmedUpcoming: appointmentsConfirmedUpcoming,
        completedThisMonth: appointmentsCompletedThisMonth,
      },
      community: {
        totalPosts: communityPostsCount,
        postsThisWeek: communityPostsThisWeek,
        totalComments: communityCommentsCount,
      },
      announcements: {
        total: announcementsCount,
        criticalUnacknowledged: criticalAnnouncementsUnacknowledged,
      },
      recentActivity: activity,
      // Geriye dönük uyumluluk: eski dashboard sürümü bu düz alanları okuyordu.
      dealersCount: dealersActive,
      documentsCount,
      aiQuestionsToday,
      activeConversations,
    };
  }

  /**
   * En çok favorilenen 5 doküman. `Favorite` modelinde Document'a doğrudan
   * bir Prisma ilişkisi tanımlı değil (sadece `documentId` skaler alanı
   * var) — bu yüzden `groupBy` ile sayıp, sonra dokümanların kendisini
   * ayrıca çekiyoruz. Böylece şemaya yeni bir ilişki eklemeye (migration
   * gerektirir) gerek kalmadı.
   */
  private async getTopFavoritedDocuments() {
    const grouped = await this.prisma.favorite.groupBy({
      by: ['documentId'],
      where: { documentId: { not: null } },
      _count: { documentId: true },
      orderBy: { _count: { documentId: 'desc' } },
      take: 5,
    });
    if (grouped.length === 0) return [];

    const documents = await this.prisma.document.findMany({
      where: { id: { in: grouped.map((g) => g.documentId!) } },
      select: { id: true, title: true, brand: true, model: true },
    });
    const countMap = new Map(grouped.map((g) => [g.documentId, g._count.documentId]));

    return documents
      .map((d) => ({ ...d, favoriteCount: countMap.get(d.id) ?? 0 }))
      .sort((a, b) => b.favoriteCount - a.favoriteCount);
  }

  /** Bir bayinin kendi kullanım özeti — bu ay kaç soru sordu, en çok hangi markayla ilgili. */
  async myStats(userId: string) {
    const startOfMonth = new Date();
    startOfMonth.setDate(1);
    startOfMonth.setHours(0, 0, 0, 0);

    const [questionsThisMonth, favoritesCount, conversations] = await Promise.all([
      this.prisma.message.count({
        where: {
          senderId: userId,
          senderType: 'USER',
          conversation: { type: 'AI' },
          createdAt: { gte: startOfMonth },
        },
      }),
      this.prisma.favorite.count({ where: { userId } }),
      this.prisma.conversation.count({
        where: { type: 'AI', participants: { some: { userId } } },
      }),
    ]);

    return { questionsThisMonth, favoritesCount, totalAiConversations: conversations };
  }

  /**
   * Rozetler/başarımlar: veritabanında ayrı bir tablo tutmuyoruz, mevcut
   * verilerden (toplam soru, yorum, favori sayısı, üyelik süresi) anlık
   * hesaplıyoruz — hem daha basit hem her zaman güncel.
   */
  async myBadges(userId: string) {
    const [totalQuestions, totalComments, totalFavorites, user] = await Promise.all([
      this.prisma.message.count({ where: { senderId: userId, senderType: 'USER', conversation: { type: 'AI' } } }),
      this.prisma.communityComment.count({ where: { authorId: userId } }),
      this.prisma.favorite.count({ where: { userId } }),
      this.prisma.user.findUnique({ where: { id: userId }, select: { createdAt: true } }),
    ]);

    const memberDays = user ? Math.floor((Date.now() - user.createdAt.getTime()) / (1000 * 60 * 60 * 24)) : 0;

    const badges = [
      { id: 'first_question', label: 'İlk Sorusunu Sordu', icon: '🎯', earned: totalQuestions >= 1 },
      { id: 'curious', label: '10 Soru Sordu', icon: '🧠', earned: totalQuestions >= 10 },
      { id: 'expert', label: '50 Soru Sordu', icon: '🏆', earned: totalQuestions >= 50 },
      { id: 'helper', label: 'Topluluğa 5 Yorum Yaptı', icon: '🤝', earned: totalComments >= 5 },
      { id: 'collector', label: '10 Favori Ekledi', icon: '⭐', earned: totalFavorites >= 10 },
      { id: 'veteran', label: '1 Yıldır Üye', icon: '🎖️', earned: memberDays >= 365 },
    ];

    return { badges, earnedCount: badges.filter((b) => b.earned).length, totalCount: badges.length };
  }

  /**
   * "Bu Yıl" özet ekranı için — Spotify Wrapped tarzı, kullanıcının o yılki
   * kullanım özetini çıkarır.
   */
  async yearInReview(userId: string) {
    const startOfYear = new Date(new Date().getFullYear(), 0, 1);

    const [questionsThisYear, favoritesThisYear, commentsThisYear, mostActiveMonth] = await Promise.all([
      this.prisma.message.count({
        where: { senderId: userId, senderType: 'USER', conversation: { type: 'AI' }, createdAt: { gte: startOfYear } },
      }),
      this.prisma.favorite.count({ where: { userId, createdAt: { gte: startOfYear } } }),
      this.prisma.communityComment.count({ where: { authorId: userId, createdAt: { gte: startOfYear } } }),
      this.prisma.message.groupBy({
        by: ['createdAt'],
        where: { senderId: userId, senderType: 'USER', conversation: { type: 'AI' }, createdAt: { gte: startOfYear } },
        _count: true,
      }),
    ]);

    // En aktif ayı bulmak için mesajları ay bazında grupluyoruz (JS tarafında —
    // Prisma'nın groupBy'ı doğrudan "ay" bazında gruplamayı desteklemiyor).
    const monthCounts = new Map<number, number>();
    for (const row of mostActiveMonth) {
      const month = new Date(row.createdAt).getMonth();
      monthCounts.set(month, (monthCounts.get(month) ?? 0) + row._count);
    }
    const monthNames = [
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
    ];
    let mostActiveMonthName: string | null = null;
    let maxCount = 0;
    for (const [month, count] of monthCounts.entries()) {
      if (count > maxCount) {
        maxCount = count;
        mostActiveMonthName = monthNames[month];
      }
    }

    return {
      year: new Date().getFullYear(),
      questionsAsked: questionsThisYear,
      favoritesAdded: favoritesThisYear,
      commentsWritten: commentsThisYear,
      mostActiveMonth: mostActiveMonthName,
    };
  }
}
