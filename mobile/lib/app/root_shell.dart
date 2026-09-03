import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'top_nav_bar.dart';
import '../core/theme/app_theme.dart';
import '../core/api/api_client.dart';
import '../core/api/socket_service.dart';
import '../core/auth/current_user.dart';
import '../core/events/messages_badge_bus.dart';
import '../core/events/notification_badge_bus.dart';
import '../core/events/home_scroll_to_top_bus.dart';
import '../core/notifications/notification_sound_service.dart';

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
    // Not: alt menü Adım 7 ile 4 sekmeye indirildi: 0=Ana Sayfa,
    // 1=Mesajlar, 2=Dokümanlar, 3=Profil.
    if (widget.navigationShell.currentIndex == 1) return;
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

  /// Adım 7 ile bu artık alt menüden çağrılmıyor (menü 4 sekmeye indirildi).
  /// Fonksiyon ve numara kasıtlı olarak silinmedi — ENTPA'yı arama kısayolu
  /// ileride uygun bir ekrana (örn. Teknik Destek üst çubuğu) taşınabilir.
  // ignore: unused_element
  Future<void> _callSupport() async {
    final uri = Uri(scheme: 'tel', path: kEntpaSupportPhoneNumber);
    try {
      await launchUrl(uri);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Arama başlatılamadı. Cihazınızda bir telefon uygulaması olduğundan emin olun.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Adım 7 (kart tasarımı kılavuzu): alt menü artık tam olarak 4 gerçek
    // sekmeye karşılık geliyor — eskiden buradaki ekstra "ENTPA'yı Ara"
    // eylemi ve "AI" sekmesi için elle tutulan görünen-sıra/dal-sırası
    // eşlemesine artık gerek yok, 1:1 karşılık geliyor.
    final selectedDestination = widget.navigationShell.currentIndex;

    void handleTap(int index) {
      if (index == 0 && widget.navigationShell.currentIndex == 0) {
        HomeScrollToTopBus.fire();
      }
      if (index == 1) setState(() => _unreadMessages = 0);
      widget.navigationShell.goBranch(
        index,
        initialLocation: index == widget.navigationShell.currentIndex,
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
    return Scaffold(
      body: widget.navigationShell,
      extendBody: false,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.outline)),
        ),
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              _NavTab(
                icon: Icons.home_outlined,
                selectedIcon: Icons.home_rounded,
                label: 'Ana Sayfa',
                selected: selectedDestination == 0,
                onTap: () => handleTap(0),
              ),
              _NavTab(
                icon: Icons.chat_bubble_outline,
                selectedIcon: Icons.chat_bubble_rounded,
                label: 'Mesajlar',
                selected: selectedDestination == 1,
                onTap: () => handleTap(1),
                badgeCount: _unreadMessages,
              ),
              _NavTab(
                icon: Icons.description_outlined,
                selectedIcon: Icons.description_rounded,
                label: 'Dokümanlar',
                selected: selectedDestination == 2,
                onTap: () => handleTap(2),
              ),
              _NavTab(
                icon: Icons.person_outline,
                selectedIcon: Icons.person_rounded,
                label: 'Profil',
                selected: selectedDestination == 3,
                onTap: () => handleTap(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Alt menü sekmesi — 22px ikon + 10.5/w600 etiket. Aktifken
/// `AppColors.primary`, pasifken `AppColors.textMuted`.
class _NavTab extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;

  const _NavTab({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textMuted;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Badge(
                isLabelVisible: badgeCount > 0,
                label: Text(badgeCount > 9 ? '9+' : '$badgeCount'),
                child: Icon(selected ? selectedIcon : icon, size: 22, color: color),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
