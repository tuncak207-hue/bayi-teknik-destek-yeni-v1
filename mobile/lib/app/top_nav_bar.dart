import 'package:flutter/material.dart';
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Bayi Teknik Destek',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
            ),
          ),
          IconButton(
            tooltip: 'Bildirimler',
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

class _TopNavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final int badgeCount;

  const _TopNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Tooltip(
          message: label,
          child: Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primaryContainer : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isSelected ? selectedIcon : icon,
                    size: 22,
                    color: isSelected ? AppColors.primary : AppColors.textMuted,
                  ),
                ),
                if (badgeCount > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      constraints: const BoxConstraints(minWidth: 15),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Text(
                        badgeCount > 9 ? '9+' : '$badgeCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
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
