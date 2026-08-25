import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'dart:async';
import '../../app/top_nav_bar.dart';
import 'home_slideshow.dart';
import '../../core/api/api_client.dart';
import '../../core/api/socket_service.dart';
import '../../core/notifications/notification_sound_service.dart';
import '../../core/events/notification_badge_bus.dart';
import '../../core/auth/current_user.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_components.dart';
import '../../core/storage/stat_badge_tracker.dart';
import '../announcements/critical_announcement_gate.dart';
import 'quick_actions_data.dart';
import '../../core/events/home_scroll_to_top_bus.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Dio _dio = ApiClient().dio;
  final _badgeTracker = StatBadgeTracker();
  Map<String, dynamic>? _stats;
  bool _statsError = false;
  Map<String, bool> _hasNewBadge = {};
  List<dynamic> _pinnedDocuments = [];
  List<QuickActionDef> _quickActionsOrder = kAllQuickActions;
  Map<String, int> _categoryBadges = {};
  final ScrollController _scrollController = ScrollController();

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadStats();
    _loadPinnedDocuments();
    _loadQuickActionsOrder();
    // Randevu/eğitim içeriği/sertifika gibi bildirimler her ekrandan
    // (RootShell) dinlendiği için, buradan gelen sinyalle kart
    // rozetlerini tazeliyoruz — Ana Sayfa şu an görünür olmasa bile.
    NotificationBadgeBus.trigger.addListener(_loadCategoryBadges);
    // Ana Sayfa açıldığında henüz onaylanmamış kritik duyuru varsa
    // kapatılamayan bir uyarı göster.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) CriticalAnnouncementGate.checkAndShow(context);
    });
    _loadCategoryBadges();
    // Alt menüdeki rozet mesaj geldiğinde anlık güncelleniyordu ama bu
    // karttaki rozet sadece ekran ilk açıldığında bir kere yükleniyordu —
    // Ana Sayfa'dayken mesaj gelirse kart hiç haberdar olmuyordu. Artık
    // burada da aynı soket sinyalini dinliyoruz.
    SocketService().connect();
    _messageSub = SocketService().onMessage.listen(_onSocketMessage);
    HomeScrollToTopBus.trigger.addListener(_scrollToTop);
  }

  StreamSubscription<Map<String, dynamic>>? _messageSub;

  void _onSocketMessage(Map<String, dynamic> message) {
    final senderId = message['senderId'];
    final senderType = message['senderType'];
    if (senderType != 'USER') return;
    if (senderId == null || senderId == CurrentUser().id) return;
    if (!mounted) return;
    // ÖNEMLİ: Önceden burada yerel "+1" ekleniyordu — bu, sayının yanlış
    // artmasına yol açabiliyordu ("1 mesaj geldi ama kartta 2 yazıyor"
    // hatası). Artık her zaman sunucudaki gerçek sayıyı yeniden çekiyoruz.
    _loadCategoryBadges();
    NotificationSoundService().play();
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    _scrollController.dispose();
    NotificationBadgeBus.trigger.removeListener(_loadCategoryBadges);
    HomeScrollToTopBus.trigger.removeListener(_scrollToTop);
    super.dispose();
  }

  /// "Mesajlar", "Bayilere Sor", "Gruplar" kartlarının üzerinde gösterilen
  /// rozet sayıları — her biri kendi bildirim türüne göre ayrı hesaplanıyor.
  Future<void> _loadCategoryBadges() async {
    try {
      final res = await _dio.get('/notifications/unread-counts-by-category');
      if (mounted) {
        setState(() => _categoryBadges = {
              'messages': res.data['messages'] ?? 0,
              'community': res.data['community'] ?? 0,
              'groups': res.data['groups'] ?? 0,
              'appointments': res.data['appointments'] ?? 0,
              'training': res.data['training'] ?? 0,
              'specialty': res.data['certification'] ?? 0,
              'announcements': res.data['announcements'] ?? 0,
              'sales_consultant': res.data['salesConsultant'] ?? 0,
              'support_tickets': res.data['supportTickets'] ?? 0,
            });
      }
    } catch (_) {
      // Rozetler ikincil bir bilgi, sessizce yut.
    }
  }

  Future<void> _loadPinnedDocuments() async {
    try {
      final res = await _dio.get('/favorites/pinned');
      if (mounted) setState(() => _pinnedDocuments = res.data);
    } catch (_) {
      // Sabitlenmiş dokümanlar ikincil bir bilgi, sessizce yut.
    }
  }

  Future<void> _loadQuickActionsOrder() async {
    final order = await QuickActionsOrder.getOrdered();
    if (mounted) setState(() => _quickActionsOrder = order);
  }

  /// Favoriler'in özel bir davranışı var (rozet işaretleme + dönüşte
  /// istatistikleri yenileme) — diğer tüm işlemler için basitçe rotaya gider.
  Future<void> _handleQuickActionTap(QuickActionDef action) async {
    if (action.id == 'favorites') {
      await _markStatSeen('favoritesCount');
      await context.push('/favorites');
      _loadStats();
      _loadPinnedDocuments();
      return;
    }
    await context.push(action.route);
    // Mesajlar/Bayilere Sor/Gruplar'dan dönünce rozetleri tazele — kart
    // üzerindeki sayı, kullanıcı o alanı ziyaret ettikten sonra doğru
    // yansımalı.
    if (action.id == 'messages' ||
        action.id == 'community' ||
        action.id == 'groups' ||
        action.id == 'appointments' ||
        action.id == 'training' ||
        action.id == 'specialty' ||
        action.id == 'announcements' ||
        action.id == 'sales_consultant') {
      _loadCategoryBadges();
    }
  }

  Future<void> _loadStats({int attempt = 0}) async {
    try {
      final res = await _dio.get('/stats/me');
      if (!mounted) return;
      final data = res.data as Map<String, dynamic>;
      // Her istatistik için, sunucudan gelen sayı daha önce görülenden
      // büyükse "yeni" rozetini yak.
      final badges = <String, bool>{};
      for (final key in ['questionsThisMonth', 'favoritesCount', 'totalAiConversations']) {
        final value = (data[key] ?? 0) as int;
        badges[key] = await _badgeTracker.hasNewValue(key, value);
      }
      setState(() {
        _stats = data;
        _hasNewBadge = badges;
        _statsError = false;
      });
    } catch (_) {
      // ÖNEMLİ DÜZELTME: "istatistikler çıkmıyor, tekrar dene ile
      // çıkıyor" — bu, uygulama soğuk açılışında ilk isteğin (bağlantı
      // tam hazır olmadan atıldığı için) başarısız olup, birkaç saniye
      // sonraki elle denemenin çalışması anlamına geliyordu — klasik bir
      // "soğuk başlangıç" zamanlama sorunu. Kullanıcı hiçbir şey
      // yapmadan, otomatik olarak birkaç kez (artan bekleme ile) tekrar
      // deniyoruz; sadece bunlar da başarısız olursa hata gösteriyoruz.
      if (!mounted) return;
      if (attempt < 2) {
        await Future.delayed(Duration(milliseconds: 800 * (attempt + 1)));
        if (mounted) _loadStats(attempt: attempt + 1);
        return;
      }
      setState(() => _statsError = true);
    }
  }

  /// Kullanıcı bir istatistik kartına girip baktığında, o kartın rozetini
  /// "görüldü" olarak işaretler — bir dahaki Ana Sayfa açılışında tekrar
  /// çıkmasın diye.
  Future<void> _markStatSeen(String key) async {
    if (_stats == null) return;
    final value = (_stats![key] ?? 0) as int;
    await _badgeTracker.markSeen(key, value);
    if (mounted) setState(() => _hasNewBadge[key] = false);
  }

  @override
  Widget build(BuildContext context) {
    // Kullanıcı isteği: "üst menü ana menünün bir parçası gibi hareket
    // etmeli" — RootShell'in paylaştığı veriyi (seçili sekme, rozet
    // sayıları, dokunma işleyicileri) buradan okuyup, üst menüyü
    // CustomScrollView'ın İLK sliver'ı olarak gömüyoruz. Bu, menünün
    // Ana Sayfa'nın kaydırma fiziğinin GERÇEK bir parçası olmasını
    // sağlıyor (SliverAppBar floating+snap) — parmakla birebir hareket.
    final navData = RootNavData.current!;
    return Scaffold(
      // Kullanıcı isteği: "Ana background çok hafif kırık beyaz/off-white
      // olabilir." AppColors.background artık bu hafif tonu taşıyor.
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.only(top: 8),
            sliver: TopNavSliverAppBar(
            selectedDestination: navData.selectedDestination,
            unreadMessages: navData.unreadMessages,
            unreadNotifications: navData.unreadNotifications,
            onTap: navData.onTap,
            onNotificationsTap: navData.onNotificationsTap,
          ),
          ),
          SliverSafeArea(
            top: false,
            sliver: SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.md),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
            // Kullanıcı isteği: "tüm menüler için uygulayalım" — diğer
            // liste ekranlarındaki (Bayiler, Gruplar vb.) büyük başlık
            // dili, ortak üst menüye geçen bu ekranda da tutarlılık için
            // geri eklendi.
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm, left: 2),
              child: Text(
                'Ana Sayfa',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: AppColors.navy, letterSpacing: -0.35, height: 1.15),
              ),
            ),
            // Kullanıcı isteği: "uygulama açılırken ekranda slayt
            // dönsün" — admin panelden yönetilen, otomatik dönen
            // tanıtım slaytları, Ana Sayfa'nın en üstünde.
            const HomeSlideshow(),
            const SizedBox(height: AppSpacing.sm),
            // AI'a Sor — kullanıcı isteği: "hiçbir yerde gölge olmayacak,
            // arka fon bembeyaz." Eski gradyanlı/gölgeli lacivert kart
            // tamamen kaldırıldı, düz turuncu (marka rengi), gölgesiz,
            // sade bir kart ile değiştirildi.
            InkWell(
              onTap: () => context.push('/ai-quick'),
              borderRadius: BorderRadius.circular(AppRadius.xl),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  // Kullanıcı isteği: "Kontrollü radius, çok hafif
                  // elevation... Premium ve kurumsal görünmeli." — aşırı
                  // efekt yok, sadece çok ince bir gölge ile bannerın
                  // sayfadan hafifçe ayrılması sağlandı.
                  boxShadow: [
                    BoxShadow(color: AppColors.primary.withValues(alpha: 0.20), blurRadius: 16, offset: const Offset(0, 6)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(AppRadius.sm)),
                      child: const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: AppSpacing.sm + 2),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI Teknik Asistan',
                            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.25),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Saniyeler içinde teknik cevap alın',
                            style: TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500, height: 1.2),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white.withValues(alpha: 0.85)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            // İstatistikler — kullanıcı isteği üzerine (dashboard tarzı)
            // en üste, göze ilk çarpan yere taşındı.
            const Text('BU AY', style: AppText.eyebrow),
            const SizedBox(height: AppSpacing.xs),
            _stats == null
                ? (_statsError
                    ? AppErrorState(
                        message: 'İstatistikler yüklenemedi.',
                        onRetry: _loadStats,
                      )
                    : const AppLoadingState(lines: 1))
                : Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.smart_toy_outlined,
                          value: '${_stats!['questionsThisMonth'] ?? 0}',
                          label: 'AI Sorusu',
                          showBadge: _hasNewBadge['questionsThisMonth'] == true,
                          onTap: () async {
                            await _markStatSeen('questionsThisMonth');
                            if (mounted) context.push('/ai-quick');
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.bookmark_border,
                          value: '${_stats!['favoritesCount'] ?? 0}',
                          label: 'Favori',
                          showBadge: _hasNewBadge['favoritesCount'] == true,
                          onTap: () async {
                            await _markStatSeen('favoritesCount');
                            await context.push('/favorites');
                            _loadStats();
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.forum_outlined,
                          value: '${_stats!['totalAiConversations'] ?? 0}',
                          label: 'Toplam Sohbet',
                          showBadge: _hasNewBadge['totalAiConversations'] == true,
                          onTap: () async {
                            await _markStatSeen('totalAiConversations');
                            if (mounted) context.push('/ai-quick');
                          },
                        ),
                      ),
                    ],
                  ),
            const SizedBox(height: 4),
            // Hızlı İşlemler — daha sıkı dashboard ritmi.
            // kaldırıldı, "Düzenle" yazısı yerine sadece ikon konuldu,
            // ve AI butonunun hemen altına (yukarı) taşındı.
            // Kullanıcı isteği: "Filtre ikonu havada duruyorsa, ilgili
            // section başlığı ya da hızlı işlemler alanıyla görsel
            // olarak hizala." — küçük bir bağlam etiketi eklenip ikonla
            // aynı satıra alındı, artık tek başına havada değil.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('HIZLI İŞLEMLER', style: AppText.eyebrow),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: IconButton(
                    onPressed: () async {
                      await context.push('/reorder-quick-actions');
                      _loadQuickActionsOrder();
                    },
                    icon: const Icon(Icons.tune, size: 18, color: AppColors.textSecondary),
                    tooltip: 'Sıralamayı Düzenle',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(width: 28, height: 28),
                    visualDensity: VisualDensity.standard,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 0),
            Transform.translate(
              offset: const Offset(0, 4),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisExtent: 150,
                  mainAxisSpacing: AppSpacing.sm,
                  crossAxisSpacing: AppSpacing.sm,
                ),
                itemCount: _quickActionsOrder
                    .where((action) => action.id != 'dealer_visits' || CurrentUser().role == 'SALES' || CurrentUser().role == 'ADMIN')
                    .length,
                itemBuilder: (context, index) {
                  final action = _quickActionsOrder
                      .where((action) => action.id != 'dealer_visits' || CurrentUser().role == 'SALES' || CurrentUser().role == 'ADMIN')
                      .elementAt(index);
                  return _QuickAction(
                    icon: action.icon,
                    label: action.label,
                    badgeCount: _categoryBadges[action.id] ?? 0,
                    onTap: () {
                      if (_categoryBadges.containsKey(action.id) && (_categoryBadges[action.id] ?? 0) > 0) {
                        setState(() => _categoryBadges[action.id] = 0);
                      }
                      _handleQuickActionTap(action);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            if (_pinnedDocuments.isNotEmpty) ...[
              const Text('Sabitlenmiş Dokümanlar', style: AppText.sectionTitle),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 88,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _pinnedDocuments.length,
                  separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final doc = _pinnedDocuments[index]['document'];
                    if (doc == null) return const SizedBox.shrink();
                    return InkWell(
                      onTap: () => context.push('/documents/${doc['id']}'),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                      child: Container(
                        width: 150,
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                          boxShadow: AppShadows.subtle,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.push_pin, size: 14, color: AppColors.brand),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '${doc['brand']}',
                                    style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              doc['title'] ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.navy),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            // "Bugün Benim İçin" özeti.
            const _TodayForMeSection(),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final VoidCallback? onTap;
  final bool showBadge;

  const _StatCard({required this.icon, required this.value, required this.label, this.onTap, this.showBadge = false});

  @override
  Widget build(BuildContext context) {
    // Kullanıcı isteği: "BU AY bölümünü profesyonel dashboard componenti
    // gibi tasarla... Sayılar daha güçlü ve görünür olmalı. Label'lar
    // daha küçük ve muted olmalı. İkonlar sayılarla yarışmamalı." Kart
    // artık kenarlıksız + çok hafif gölgeli, ikon küçük/soluk, rakam
    // güçlü/kalın, etiket küçük/muted.
    return Material(
      color: const Color(0xFFF8F7FC),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.outline.withValues(alpha: 0.72)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.035), blurRadius: 10, offset: const Offset(0, 3))],
          ),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: ReferenceCardContent(
                  icon: icon,
                  title: value,
                  description: label,
                  iconColor: AppColors.textMuted,
                  iconBackground: AppColors.primarySoft,
                  compact: true,
                ),
              ),
              if (showBadge)
                Positioned(
                  top: -2,
                  right: 8,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(color: AppColors.brand, shape: BoxShape.circle),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badgeCount;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8F7FC),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.outline.withValues(alpha: 0.72)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.035),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: ReferenceCardContent(
                  icon: icon,
                  title: label,
                  iconColor: AppColors.primary,
                  iconBackground: AppColors.primarySoft,
                  compact: true,
                  titleAsLabel: true,
                ),
              ),
              if (badgeCount > 0)
                Positioned(
                  top: -5,
                  right: -5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    constraints: const BoxConstraints(minWidth: 18),
                    decoration: BoxDecoration(
                      color: AppColors.brand,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Bugün Benim İçin" özeti (#17) — bugünkü randevular, açık teknik
/// destek kayıtları, SLA riski, okunmamış bildirim sayısı. Mevcut Ana
/// Sayfa kartlarına dokunulmadan, üstüne eklenen bağımsız bir bölüm.
class _TodayForMeSection extends StatefulWidget {
  const _TodayForMeSection();

  @override
  State<_TodayForMeSection> createState() => _TodayForMeSectionState();
}

class _TodayForMeSectionState extends State<_TodayForMeSection> {
  final Dio _dio = ApiClient().dio;
  Map<String, dynamic>? _summary;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await _dio.get('/dashboard/for-me');
      if (mounted) setState(() => _summary = res.data);
    } catch (_) {
      // Sessizce yoksay — bu özet ek bir bilgi katmanı, başarısız olursa
      // Ana Sayfa'nın geri kalanını etkilememeli.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_summary == null) return const SizedBox.shrink();
    final appointments = (_summary!['todaysAppointments'] as List?) ?? [];
    final openTickets = _summary!['openTicketsCount'] ?? 0;
    final slaRisk = _summary!['slaRiskTicketsCount'] ?? 0;

    if (appointments.isEmpty && openTickets == 0 && slaRisk == 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppShadows.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.today_outlined, size: 16, color: AppColors.brand),
              const SizedBox(width: 6),
              const Text('Bugün Benim İçin', style: AppText.eyebrow),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (appointments.isNotEmpty) _summaryChip(Icons.event_outlined, '${appointments.length} bugünkü randevu', AppColors.navy),
              if (openTickets > 0) _summaryChip(Icons.build_outlined, '$openTickets açık teknik destek', AppColors.brand),
              if (slaRisk > 0) _summaryChip(Icons.warning_amber_rounded, '$slaRisk kayıtta SLA riski', Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}



