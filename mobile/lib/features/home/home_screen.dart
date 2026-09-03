import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'dart:async';
import '../../app/top_nav_bar.dart';
import 'home_slideshow.dart';
import '../../core/api/api_client.dart';
import '../../core/api/socket_service.dart';
import '../../core/notifications/notification_sound_service.dart';
import '../../core/events/notification_badge_bus.dart';
import '../../core/events/stats_refresh_bus.dart';
import '../../core/auth/current_user.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_components.dart';
import '../../core/storage/stat_badge_tracker.dart';
import '../../core/storage/local_category_badge_store.dart';
import '../announcements/critical_announcement_gate.dart';
import 'quick_actions_data.dart';
import '../../core/events/home_scroll_to_top_bus.dart';
import '../../l10n/app_localizations.dart';

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
  Map<String, int> _localBadges = {};
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
    _loadQuickActionsOrder();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 250), () {
        if (!mounted) return;
        _loadPinnedDocuments();
        _loadCategoryBadges();
      });
    });
    NotificationBadgeBus.trigger.addListener(_loadCategoryBadges);
    StatsRefreshBus.trigger.addListener(_onStatsRefreshBump);
    LocalCategoryBadgeStore().trigger.addListener(_loadLocalBadges);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) CriticalAnnouncementGate.checkAndShow(context);
    });
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
    _loadCategoryBadges();
    NotificationSoundService().play();
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    _scrollController.dispose();
    NotificationBadgeBus.trigger.removeListener(_loadCategoryBadges);
    StatsRefreshBus.trigger.removeListener(_onStatsRefreshBump);
    LocalCategoryBadgeStore().trigger.removeListener(_loadLocalBadges);
    HomeScrollToTopBus.trigger.removeListener(_scrollToTop);
    super.dispose();
  }

  // Kullanıcı isteği: "Ana Sayfa'da aşağıya çekince sayfa yenilemesi
  // istiyorum, gelmeyen bildirim varsa yenilenince gelsin" — asıl öncelik
  // zaten anlık soket bildirimleri (bunlar zaten çalışıyor); bu, sadece
  // soket bir şekilde bağlantıyı kaçırırsa kullanıcının elle "her şeyi
  // tazele" diyebilmesi için bir yedek/tamamlayıcı mekanizma. Tüm
  // kartları (istatistikler, rozetler, sabitlenmiş dokümanlar) paralel
  // olarak yeniden çekiyor.
  Future<void> _onPullToRefresh() async {
    // Üst çubuktaki zil ikonu sayısının da tazelenmesi için — bu,
    // root_shell.dart'taki dinleyiciyi tetikliyor.
    NotificationBadgeBus.bump();
    await Future.wait([
      _loadStats(),
      _loadCategoryBadges(),
      _loadPinnedDocuments(),
    ]);
  }

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
              'quotes': res.data['quotes'] ?? 0,
            });
      }
    } catch (_) {}
    _loadLocalBadges();
  }

  // Kullanıcı isteği: "dosya indirdiğimde/favoriye eklediğimde ilgili
  // kartta rozet olmalı" — bunlar backend'de "okunmadı bildirimi" olarak
  // izlenmediği için (indirme tamamen yerel, favori ise ayrı bir
  // istatistik), tamamen cihazda tutulan basit bir sayaçla besleniyor.
  Future<void> _loadLocalBadges() async {
    final offlineDocs = await LocalCategoryBadgeStore().get('offline_docs');
    final favorites = await LocalCategoryBadgeStore().get('favorites');
    if (mounted) {
      setState(() => _localBadges = {
            'offline_docs': offlineDocs,
            'favorites': favorites,
          });
    }
  }

  Future<void> _loadPinnedDocuments() async {
    try {
      final res = await _dio.get('/favorites/pinned');
      if (mounted) setState(() => _pinnedDocuments = res.data);
    } catch (_) {}
  }

  Future<void> _loadQuickActionsOrder() async {
    final order = await QuickActionsOrder.getOrdered();
    if (mounted) setState(() => _quickActionsOrder = order);
  }

  Future<void> _handleQuickActionTap(QuickActionDef action) async {
    if (action.id == 'favorites') {
      await _markStatSeen('favoritesCount');
      await context.push('/favorites');
      _loadStats();
      _loadPinnedDocuments();
      return;
    }
    await context.push(action.route);
    if (action.id == 'messages' ||
        action.id == 'community' ||
        action.id == 'groups' ||
        action.id == 'appointments' ||
        action.id == 'training' ||
        action.id == 'specialty' ||
        action.id == 'announcements' ||
        action.id == 'sales_consultant' ||
        action.id == 'support_tickets' ||
        action.id == 'quotes') {
      _loadCategoryBadges();
    }
  }

  void _onStatsRefreshBump() => _loadStats();

  Future<void> _loadStats({int attempt = 0}) async {
    if (attempt == 0 && _stats == null) {
      try {
        final userKey = CurrentUser().id;
        if (userKey != null) {
          final prefs = await SharedPreferences.getInstance();
          final cached = prefs.getString('home_stats_$userKey');
          if (cached != null && mounted && _stats == null) {
            final data = Map<String, dynamic>.from(jsonDecode(cached) as Map);
            setState(() {
              _stats = data;
              _statsError = false;
            });
          }
        }
      } catch (_) {}
    }
    try {
      final res = await _dio.get('/stats/me');
      if (!mounted) return;
      final data = res.data as Map<String, dynamic>;
      final badges = <String, bool>{};
      for (final key in ['questionsThisMonth', 'favoritesCount', 'supportTicketsCount']) {
        final value = (data[key] ?? 0) as int;
        badges[key] = await _badgeTracker.hasNewValue(key, value);
      }
      setState(() {
        _stats = data;
        _hasNewBadge = badges;
        _statsError = false;
      });
      try {
        final userKey = CurrentUser().id;
        if (userKey != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('home_stats_$userKey', jsonEncode(data));
        }
      } catch (_) {}
    } catch (_) {
      if (!mounted) return;
      if (attempt < 4) {
        await Future.delayed(Duration(milliseconds: 400 * (1 << attempt)));
        if (mounted) _loadStats(attempt: attempt + 1);
        return;
      }
      setState(() => _statsError = true);
    }
  }

  Future<void> _markStatSeen(String key) async {
    if (_stats == null) return;
    final value = (_stats![key] ?? 0) as int;
    await _badgeTracker.markSeen(key, value);
    if (mounted) setState(() => _hasNewBadge[key] = false);
  }

  @override
  Widget build(BuildContext context) {
    final navData = RootNavData.current!;
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _onPullToRefresh,
        child: CustomScrollView(
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
            _GreetingHeader(user: CurrentUser()),
            const SizedBox(height: AppSpacing.sm),
            const HomeSlideshow(),
            const SizedBox(height: AppSpacing.sm),
            InkWell(
              onTap: () => context.push('/ai-quick'),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 13),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.outlineStrong),
                  boxShadow: AppShadows.subtle,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(AppRadius.sm)),
                      child: const Icon(Icons.auto_awesome, color: AppColors.primary, size: 19),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        l10n.aiAssistantSubtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(AppRadius.sm)),
                      child: const Text('AI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.thisMonth, style: AppText.eyebrow),
            const SizedBox(height: AppSpacing.xs),
            _stats == null
                ? (_statsError
                    ? AppErrorState(
                        message: 'İstatistikler yüklenemedi.',
                        onRetry: _loadStats,
                      )
                    : const AppLoadingState(lines: 1))
                : _HomeStatusStrip(
                    questions: '${_stats!['questionsThisMonth'] ?? 0}',
                    favorites: '${_stats!['favoritesCount'] ?? 0}',
                    tickets: '${_stats!['supportTicketsCount'] ?? 0}',
                    onQuestionsTap: () async {
                      await _markStatSeen('questionsThisMonth');
                      if (mounted) context.push('/ai-quick');
                    },
                    onFavoritesTap: () async {
                      await _markStatSeen('favoritesCount');
                      await context.push('/favorites');
                      _loadStats();
                    },
                    onTicketsTap: () async {
                      await _markStatSeen('supportTicketsCount');
                      if (mounted) context.push('/support-tickets');
                    },
                  ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.quickActions, style: AppText.eyebrow),
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
              child: GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 1.18,
              padding: EdgeInsets.zero,
              children: _quickActionsOrder
                  .where((action) => action.id != 'dealer_visits' || CurrentUser().role == 'SALES' || CurrentUser().role == 'ADMIN')
                  .map((action) => _QuickAction(
                        icon: action.icon,
                        label: localizedQuickActionLabel(context, action),
                        badgeCount: (_categoryBadges[action.id] ?? 0) + (_localBadges[action.id] ?? 0),
                        onTap: () {
                          if (_categoryBadges.containsKey(action.id) && (_categoryBadges[action.id] ?? 0) > 0) {
                            setState(() => _categoryBadges[action.id] = 0);
                          }
                          if (_localBadges.containsKey(action.id) && (_localBadges[action.id] ?? 0) > 0) {
                            setState(() => _localBadges[action.id] = 0);
                            LocalCategoryBadgeStore().clear(action.id);
                          }
                          _handleQuickActionTap(action);
                        },
                      ))
                  .toList(),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            if (_pinnedDocuments.isNotEmpty) ...[
              Text(AppLocalizations.of(context)!.pinnedDocuments, style: AppText.sectionTitle),
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
                          border: Border.all(color: AppColors.outlineStrong),
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
            const _TodayForMeSection(),
                ]),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _HomeStatusStrip extends StatelessWidget {
  final String questions;
  final String favorites;
  final String tickets;
  final VoidCallback onQuestionsTap;
  final VoidCallback onFavoritesTap;
  final VoidCallback onTicketsTap;

  const _HomeStatusStrip({
    required this.questions,
    required this.favorites,
    required this.tickets,
    required this.onQuestionsTap,
    required this.onFavoritesTap,
    required this.onTicketsTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Row(
        children: [
          Expanded(child: _StatusMetric(value: questions, label: l10n.statAiQuestions, onTap: onQuestionsTap)),
          _statusDivider(),
          Expanded(child: _StatusMetric(value: favorites, label: l10n.statFavorites, onTap: onFavoritesTap)),
          _statusDivider(),
          Expanded(child: _StatusMetric(value: tickets, label: l10n.statSupportTickets, onTap: onTicketsTap)),
        ],
      ),
    );
  }

  Widget _statusDivider() => Container(width: 1, height: 34, color: Colors.white.withValues(alpha: 0.22));
}

class _StatusMetric extends StatelessWidget {
  final String value;
  final String label;
  final VoidCallback onTap;

  const _StatusMetric({required this.value, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.4)),
            const SizedBox(height: 3),
            Text(label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}

class _GreetingHeader extends StatelessWidget {
  final CurrentUser user;

  const _GreetingHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    final name = user.firstName?.trim();
    final displayName = name == null || name.isEmpty ? 'ENTPA' : name;
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Günaydın' : (hour < 18 ? 'İyi günler' : 'İyi akşamlar');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textMuted)),
              const SizedBox(height: 2),
              Text(displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.navy, letterSpacing: -0.7)),
            ],
          ),
        ),
        if (user.role != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(AppRadius.xl)),
            child: Text(user.role!, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.primary)),
          ),
      ],
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
    return Material(
      color: const Color(0xFFF8F7FC),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.outlineStrong),
            boxShadow: AppShadows.subtle,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xs),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              SizedBox(
                height: 46,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: Icon(icon, color: AppColors.textMuted, size: 10)),
                    const SizedBox(height: 2),
                    Center(child: Text(value, style: AppText.statValue.copyWith(fontSize: 12.5, fontWeight: FontWeight.w800))),
                    const SizedBox(height: 1),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.statLabel.copyWith(fontSize: 8.5),
                    ),
                  ],
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
            border: Border.all(color: AppColors.outlineStrong),
            boxShadow: AppShadows.card,
          ),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: AppColors.primarySoft,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        color: AppColors.primary,
                        size: 17,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 24,
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          fontSize: 10.5,
                          color: AppColors.textPrimary,
                          height: 1.1,
                          letterSpacing: -0.15,
                        ),
                      ),
                    ),
                  ],
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
                      borderRadius: BorderRadius.circular(AppRadius.sm),
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
    } catch (_) {}
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
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outlineStrong),
        boxShadow: AppShadows.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.today_outlined, size: 16, color: AppColors.brand),
              const SizedBox(width: 6),
              Text(AppLocalizations.of(context)!.todayForMe, style: AppText.eyebrow),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (appointments.isNotEmpty) _summaryChip(Icons.event_outlined, '${appointments.length} bugünkü randevu', AppColors.navy),
              if (openTickets > 0) _summaryChip(Icons.build_outlined, '$openTickets açık teknik destek', AppColors.brand),
              if (slaRisk > 0) _summaryChip(Icons.warning_amber_rounded, '$slaRisk kayıtta SLA riski', AppColors.navy),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(AppRadius.xl)),
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
