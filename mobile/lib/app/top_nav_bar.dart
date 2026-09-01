import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../core/theme/app_theme.dart';

/// Kullanıcı isteği: "üst menü barı ana menüden bağımsız olmamalı, ana
/// menünün bir parçası gibi hareket etmeli." Önceki yaklaşım (kaydırma
/// olayını dinleyip menünün yüksekliğini elle güncellemek) sadece bir
/// TAKLİTTİ — gerçek bir "birlikte kayan" his vermiyordu. Bu widget,
/// Flutter'ın YERLEŞİK mekanizmasını (SliverAppBar + floating + snap)
/// kullanıyor — bu, menüyü ekranın kaydırma fiziğinin GERÇEK bir parçası
/// yapıyor, parmakla birebir hareket ediyor, taklit değil.
///
/// Her sekme ekranı (Ana Sayfa, AI, Mesajlar, Profil), kendi
/// CustomScrollView'ının İLK sliver'ı olarak bunu kullanmalı.
class TopNavSliverAppBar extends StatelessWidget {
  final int selectedDestination;
  final int unreadMessages;
  final int unreadNotifications;
  final void Function(int index) onTap;
  final VoidCallback onNotificationsTap;

  const TopNavSliverAppBar({
    super.key,
    required this.selectedDestination,
    required this.unreadMessages,
    required this.unreadNotifications,
    required this.onTap,
    required this.onNotificationsTap,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      // ÖNEMLİ DÜZELTME: "tamamen yukarı kaydırmadan üst menü barı
      // belirmesin" — floating+snap, herhangi bir küçük yukarı hareketle
      // bile menüyü anında geri getiriyordu. Artık menü SADECE listenin
      // en başına (en tepesine) dönüldüğünde tekrar görünüyor.
      floating: false,
      snap: false,
      pinned: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      surfaceTintColor: Theme.of(context).colorScheme.surface,
      elevation: 0,
      // ÖNEMLİ DÜZELTME: "Status Bar'a fazla yakın" — SliverAppBar, Status
      // Bar yüksekliğini zaten otomatik hesaba katıyor (çift SafeArea/
      // padding sorunu YOK). Menünün Status Bar'a olan tek gerçek mesafesi,
      // aşağıdaki title Padding'inin top değeriydi (önceden sadece 6px).
      // Menü KONTEYNERİNİN kendisi (ikonların içi değil) aşağı alındı.
      toolbarHeight: 72,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      title: _buildIconsRow(context),
    );
  }

  /// Ortak ikon satırı — hem kaydırılabilir (SliverAppBar) hem sabit
  /// (StaticTopNavBar) versiyon TARAFINDAN paylaşılıyor, ikisi de aynı
  /// görünüme sahip olsun diye.
  Widget _buildIconsRow(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 12, 4),
      child: Row(
        children: [
          // Kullanıcı isteği: "en solda, bildirim ikonunun yanında
          // ENTPA Teknik Mühendislik Platformu yazısı olmalı." — ayrıca
          // "İngilizce dil desteği ekle".
          Expanded(
            child: Text(
              l10n.entpaSubtitle,
              style: AppText.screenTitle.copyWith(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.35, overflow: TextOverflow.ellipsis),
            ),
          ),
          IconButton(
            tooltip: l10n.notifications,
            onPressed: onNotificationsTap,
            icon: Badge(
              isLabelVisible: unreadNotifications > 0,
              label: Text(unreadNotifications > 9 ? '9+' : '$unreadNotifications'),
              child: Icon(Icons.notifications_outlined, color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kullanıcı isteği: "üst menüdeki tüm kartlara ekle" — Mesajlar gibi,
/// kendi kaydırma yapısı (arama sonucu + koşullu liste) CustomScrollView'a
/// çevrilmesi riskli olan ekranlar için, AYNI görünüme sahip ama SABİT
/// (kaymayan) bir versiyon. Normal bir Column/Scaffold body'sinin en
/// üstüne, sıradan bir widget olarak eklenebilir.
class StaticTopNavBar extends StatelessWidget {
  final int selectedDestination;
  final int unreadMessages;
  final int unreadNotifications;
  final void Function(int index) onTap;
  final VoidCallback onNotificationsTap;

  const StaticTopNavBar({
    super.key,
    required this.selectedDestination,
    required this.unreadMessages,
    required this.unreadNotifications,
    required this.onTap,
    required this.onNotificationsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        bottom: false,
        child: TopNavSliverAppBar(
          selectedDestination: selectedDestination,
          unreadMessages: unreadMessages,
          unreadNotifications: unreadNotifications,
          onTap: onTap,
          onNotificationsTap: onNotificationsTap,
        )._buildIconsRow(context),
      ),
    );
  }
}

/// Root_shell'in tuttuğu paylaşılan durumu (seçili sekme, okunmamış
/// sayıları, dokunma işleyicileri), her sekme ekranının kendi
/// CustomScrollView'ından erişebilmesi için — prop aktarmaya gerek
/// kalmadan.
///
/// ÖNEMLİ: InheritedWidget yerine basit bir ValueNotifier tabanlı
/// paylaşılan nesne kullanılıyor — bazı çok yeni Flutter sürümlerinde
/// `dependOnInheritedWidgetOfType` ile ilgili derleme hatası
/// yaşandığı için, hiçbir sürüme bağlı olmayan, en kararlı yöntem
/// tercih edildi.
class RootNavData {
  final int selectedDestination;
  final int unreadMessages;
  final int unreadNotifications;
  final void Function(int index) onTap;
  final VoidCallback onNotificationsTap;

  const RootNavData({
    required this.selectedDestination,
    required this.unreadMessages,
    required this.unreadNotifications,
    required this.onTap,
    required this.onNotificationsTap,
  });

  /// RootShell her build olduğunda güncellenir; sekme ekranları bunu
  /// doğrudan (BuildContext'e ihtiyaç duymadan) okuyabilir.
  static RootNavData? current;
}
