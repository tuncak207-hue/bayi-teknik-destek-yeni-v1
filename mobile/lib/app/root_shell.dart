import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'top_nav_bar.dart';
import '../core/api/api_client.dart';
import '../core/api/socket_service.dart';
import '../core/auth/current_user.dart';
import '../core/events/messages_badge_bus.dart';
import '../core/events/notification_badge_bus.dart';
import '../core/events/home_scroll_to_top_bus.dart';
import '../core/notifications/notification_sound_service.dart';
import '../core/calls/video_call_service.dart';
import '../features/calls/video_call_screen.dart';

// ENTPA Mühendislik Hizmeti'nin destek hattı — alt menüdeki "ENTPA'yı Ara"
// butonuna dokununca bu numara aranır.
const String kEntpaSupportPhoneNumber = '+905497826144';

class RootShell extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const RootShell({super.key, required this.navigationShell});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  final Dio _dio = ApiClient().dio;
  int _unreadMessages = 0;
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
    _loadUnreadNotifications();
    // Önceden Mesajlar sekmesinde hiçbir anlık uyarı yoktu — B kullanıcısı
    // mesaj gönderdiğinde A, sohbeti elle açmadan bunu fark edemiyordu.
    // Socket bağlantısı artık kullanıcının TÜM sohbet odalarına otomatik
    // katıldığı için (bkz. chat.gateway.ts), buradan gelen her mesajı
    // dinleyip rozeti anlık artırabiliyoruz.
    SocketService().onMessage.listen(_onSocketMessage);
    // Mesajlar dışındaki TÜM bildirimler (randevu, eğitim içeriği,
    // sertifika uyarısı, duyuru vb.) için — uygulama açıkken, hangi
    // ekranda olursanız olun anlık ses + rozet tazelemesi.
    SocketService().onNotification.listen(_onSocketNotification);
    // Bir sohbet, Mesajlar sekmesi dışında bir yoldan da (örn. Bildirimler
    // ekranından) okunmuş olabilir — bu durumda gerçek sayıyı sunucudan
    // yeniden çekiyoruz, yerel sayaç bayatlamasın diye.
    MessagesBadgeBus.trigger.addListener(_loadUnreadCount);
    // ÖNEMLİ: Bildirim zili artık Ana Sayfa'nın kendi AppBar'ında değil,
    // burada (birleşik üst menüde) — çift başlık şeridi sorununu çözmek
    // için Ana Sayfa'nın AppBar'ı tamamen kaldırıldı.
    NotificationBadgeBus.trigger.addListener(_loadUnreadNotifications);
    VideoCallService().startListening();
    VideoCallService().onIncomingCall.listen((data) {
      final navContext = context;
      if (!navContext.mounted) return;
      Navigator.of(navContext, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (_) => VideoCallScreen(remoteName: data['callerName'] ?? 'Bilinmeyen', isIncoming: true),
          fullscreenDialog: true,
        ),
      );
    });
  }

  Future<void> _loadUnreadNotifications() async {
    try {
      final res = await _dio.get('/notifications/unread-count');
      if (mounted) setState(() => _unreadNotifications = res.data['count'] ?? 0);
    } catch (_) {
      // İkincil bir bilgi, sessizce yut.
    }
  }

  @override
  void dispose() {
    MessagesBadgeBus.trigger.removeListener(_loadUnreadCount);
    NotificationBadgeBus.trigger.removeListener(_loadUnreadNotifications);
    super.dispose();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final res = await _dio.get('/notifications/unread-message-count');
      if (mounted) setState(() => _unreadMessages = res.data['count'] ?? 0);
    } catch (_) {
      // Rozet ikincil bir bilgi, sessizce yut.
    }
  }

  void _onSocketMessage(Map<String, dynamic> message) {
    // Kendi gönderdiğimiz mesajlar veya AI mesajları rozeti artırmasın —
    // sadece BAŞKA bir kullanıcıdan gelen mesajlar için.
    final senderId = message['senderId'];
    final senderType = message['senderType'];
    if (senderType != 'USER') return;
    if (senderId == null || senderId == CurrentUser().id) return;
    // Kullanıcı zaten Mesajlar sekmesindeyse rozeti artırmaya gerek yok.
    // Not: alt menüde artık 4 gerçek sekme var (Ana Sayfa, AI, Mesajlar,
    // Profil) — Mesajlar'ın dal indeksi 2.
    if (widget.navigationShell.currentIndex == 2) return;
    // ÖNEMLİ: Önceden burada yerel olarak "+1" ekleniyordu — soket
    // bağlantısı yeniden kurulduğunda veya aynı olay birden fazla kez
    // tetiklendiğinde sayı yanlış artabiliyordu ("1 mesaj geldi ama 2
    // gösteriyor" hatasının kök sebebi buydu). Artık her zaman sunucudaki
    // GERÇEK sayıyı yeniden çekiyoruz — bu, sayının asla yanlış
    // olamayacağını garanti eder.
    _loadUnreadCount();
    NotificationSoundService().play();
  }

  /// Randevu, eğitim içeriği, sertifika uyarısı, duyuru gibi TÜM diğer
  /// bildirimler için — WhatsApp'ta olduğu gibi, uygulama neredeyse
  /// hangi ekranda olursanız olun (Ana Sayfa'da değilseniz bile) anlık
  /// ses çalar ve Ana Sayfa'nın kart rozetleri arka planda tazelenir.
  void _onSocketNotification(Map<String, dynamic> notification) {
    NotificationSoundService().play();
    NotificationBadgeBus.bump();
  }

  Future<void> _callSupport() async {
    final uri = Uri(scheme: 'tel', path: kEntpaSupportPhoneNumber);
    try {
      await launchUrl(uri);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.callStartFailed)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Alt menüde 5 buton var ama sadece 4'ü gerçek bir ekrana (dal) karşılık
    // geliyor — "ENTPA'yı Ara" bir eylem, sekme değil. Bu yüzden görünen
    // buton sırası (0..4) ile gerçek dal indeksleri (0..3) arasında elle
    // bir eşleme tutuyoruz.
    // Görünen sıra: 0=Ana Sayfa, 1=AI, 2=ENTPA'yı Ara (dal değil), 3=Mesajlar, 4=Profil
    // Dal sırası:   0=Ana Sayfa, 1=AI,                              2=Mesajlar, 3=Profil
    const branchForDestination = {0: 0, 1: 1, 3: 2, 4: 3};
    const destinationForBranch = {0: 0, 1: 1, 2: 3, 3: 4};
    final selectedDestination = destinationForBranch[widget.navigationShell.currentIndex] ?? 0;

    void handleTap(int index) {
      if (index == 2) {
        _callSupport();
        return;
      }
      final branchIndex = branchForDestination[index]!;
      if (branchIndex == 2) setState(() => _unreadMessages = 0);
      if (branchIndex == 0 && widget.navigationShell.currentIndex == 0) {
        HomeScrollToTopBus.fire();
      }
      widget.navigationShell.goBranch(
        branchIndex,
        initialLocation: branchIndex == widget.navigationShell.currentIndex,
      );
    }

    // ÖNEMLİ: InheritedWidget yerine basit bir statik alan kullanılıyor
    // (bkz. top_nav_bar.dart) — bazı Flutter sürümlerinde
    // dependOnInheritedWidgetOfType ile ilgili bir derleme sorunu
    // yaşandığı için daha kararlı bir yönteme geçildi.
    RootNavData.current = RootNavData(
      selectedDestination: selectedDestination,
      unreadMessages: _unreadMessages,
      unreadNotifications: _unreadNotifications,
      onTap: handleTap,
      onNotificationsTap: () => context.push('/notifications').then((_) => _loadUnreadNotifications()),
    );
    // ÖNEMLİ: "üst menü bağımsız olmamalı, ana menünün bir parçası
    // gibi hareket etmeli" — root_shell artık üst menüyü KENDİSİ
    // ÇİZMİYOR. Her sekme ekranı (Home vb.), TopNavSliverAppBar'ı
    // KENDİ CustomScrollView'ının ilk sliver'ı olarak gömüyor — bu
    // sayede menü, o ekranın kaydırma fiziğinin GERÇEK bir parçası
    // oluyor (SliverAppBar floating+snap), taklit bir dinleyici değil.
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: widget.navigationShell,
      extendBody: false,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedDestination,
        onDestinationSelected: handleTap,
        backgroundColor: scheme.surface,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: AppLocalizations.of(context)!.navHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.auto_awesome_outlined),
            selectedIcon: const Icon(Icons.auto_awesome),
            label: AppLocalizations.of(context)!.navAi,
          ),
          NavigationDestination(
            icon: const Icon(Icons.call_outlined),
            selectedIcon: const Icon(Icons.call),
            label: AppLocalizations.of(context)!.navSupport,
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: _unreadMessages > 0,
              label: Text(_unreadMessages > 9 ? '9+' : '$_unreadMessages'),
              child: const Icon(Icons.forum_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: _unreadMessages > 0,
              label: Text(_unreadMessages > 9 ? '9+' : '$_unreadMessages'),
              child: const Icon(Icons.forum_rounded),
            ),
            label: AppLocalizations.of(context)!.navMessages,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person_rounded),
            label: AppLocalizations.of(context)!.navProfile,
          ),
        ],
      ),
    );
  }
}
