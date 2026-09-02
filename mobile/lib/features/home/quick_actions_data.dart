import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ana Sayfa'daki Hızlı İşlemler grid'inin gösterebileceği tüm öğeler —
/// sabit bir liste. Kullanıcının Ayarlar'dan belirlediği sıra, sadece bu
/// listenin GÖSTERİM SIRASINI değiştirir, öğelerin kendisini değiştirmez.
class QuickActionDef {
  final String id;
  final IconData icon;
  final String label;
  final String route;

  const QuickActionDef({required this.id, required this.icon, required this.label, required this.route});
}

const List<QuickActionDef> kAllQuickActions = [
  // "AI'a Sor" ve "Yangın Sistemleri" kısayolları kaldırıldı — ikisi de
  // alt menüdeki AI sekmesiyle birebir aynı ekrana gidiyordu, "Yangın
  // Sistemleri" ise hiç var olmayan bir özelliği varmış gibi gösteren
  // yanıltıcı bir etiketti. Alt menüdeki "AI" sekmesi zaten tek, doğru
  // giriş noktası.
  QuickActionDef(id: 'search', icon: Icons.search, label: 'Ara', route: '/search'),
  QuickActionDef(id: 'device_history', icon: Icons.qr_code_2, label: 'Cihaz Geçmişi', route: '/device-history'),
  QuickActionDef(id: 'bulk_export', icon: Icons.folder_zip_outlined, label: 'Toplu PDF', route: '/bulk-export'),
  QuickActionDef(id: 'messages', icon: Icons.chat_bubble_outline, label: 'Mesajlar', route: '/messages'),
  // "Fotoğraf Gönder" kaldırıldı — kullanıcı isteği. Fotoğraf/galeri
  // seçimi artık doğrudan AI Sor ekranının içinde (kamera + galeri
  // seçenekleriyle birlikte).
  QuickActionDef(id: 'community', icon: Icons.forum_outlined, label: 'Bayilere Sor', route: '/community'),
  QuickActionDef(id: 'appointments', icon: Icons.calendar_month_outlined, label: 'Randevu Al', route: '/appointments'),
  QuickActionDef(id: 'groups', icon: Icons.groups_2_outlined, label: 'Gruplar', route: '/groups'),
  QuickActionDef(id: 'favorites', icon: Icons.bookmark_border, label: 'Favorilerim', route: '/favorites'),
  // "Hesaplamalar" kullanıcı isteğiyle Ana Sayfa'dan gizlendi — kod silinmedi,
  // istenirse bu satır tekrar aktif edilerek geri getirilebilir.
  // QuickActionDef(id: 'calculators', icon: Icons.calculate_outlined, label: 'Hesaplamalar', route: '/calculators'),
  QuickActionDef(id: 'announcements', icon: Icons.campaign_outlined, label: 'Duyurular', route: '/announcements'),
  QuickActionDef(id: 'offline_docs', icon: Icons.download_outlined, label: 'İndirilenlerim', route: '/offline-documents'),
  QuickActionDef(id: 'barcode', icon: Icons.qr_code_scanner, label: 'Barkod Tara', route: '/barcode-scanner'),
  QuickActionDef(id: 'commissioning', icon: Icons.checklist_outlined, label: 'Devreye Alma', route: '/commissioning'),
  // "Yangın Sistemleri" kısayolu kaldırıldı — yukarıdaki notta açıklandığı
  // gibi, gerçek bir işlevi yoktu.
  QuickActionDef(id: 'maintenance', icon: Icons.build_outlined, label: 'Bakım Geçmişi', route: '/maintenance'),
  QuickActionDef(id: 'bom', icon: Icons.list_alt_outlined, label: 'Malzeme Listesi', route: '/bom-builder'),
  QuickActionDef(id: 'specialty', icon: Icons.workspace_premium_outlined, label: 'Uzmanlık/Sertifika', route: '/specialty'),
  QuickActionDef(id: 'sales_consultant', icon: Icons.support_agent_outlined, label: 'Satış Danışmanına Sor', route: '/sales-consultants'),
  QuickActionDef(id: 'training', icon: Icons.school_outlined, label: 'Eğitim Merkezi', route: '/training'),
  QuickActionDef(id: 'wallet', icon: Icons.folder_open_outlined, label: 'Evrak Çantası', route: '/wallet'),
  QuickActionDef(id: 'support_tickets', icon: Icons.support_outlined, label: 'Teknik Destek', route: '/support-tickets'),
  QuickActionDef(id: 'quotes', icon: Icons.request_quote_outlined, label: 'Teklif Al', route: '/quotes'),
  // Sadece SALES (satış danışmanı) rolündeki kullanıcılara gösterilir —
  // bkz. home_screen.dart'taki rol filtresi.
  QuickActionDef(id: 'dealer_visits', icon: Icons.location_on_outlined, label: 'Bayi Ziyaretleri', route: '/dealer-visits'),
];

const _kOrderKey = 'quick_actions_order';

/// Kullanıcı isteği: "İngilizce dil desteği ekle" — QuickActionDef.label
/// sabit (const) bir alan olduğu için doğrudan çeviri barındıramıyor;
/// ekranda gösterilecek metin bu fonksiyonla, seçili dile göre üretiliyor.
String localizedQuickActionLabel(BuildContext context, QuickActionDef action) {
  final l10n = AppLocalizations.of(context)!;
  switch (action.id) {
    case 'search':
      return l10n.qaSearch;
    case 'messages':
      return l10n.qaMessages;
    case 'community':
      return l10n.qaCommunity;
    case 'appointments':
      return l10n.qaAppointments;
    case 'groups':
      return l10n.qaGroups;
    case 'favorites':
      return l10n.qaFavorites;
    case 'announcements':
      return l10n.qaAnnouncements;
    case 'offline_docs':
      return l10n.qaOfflineDocs;
    case 'barcode':
      return l10n.qaBarcode;
    case 'commissioning':
      return l10n.qaCommissioning;
    case 'maintenance':
      return l10n.qaMaintenance;
    case 'bom':
      return l10n.qaBom;
    case 'specialty':
      return l10n.qaSpecialty;
    case 'sales_consultant':
      return l10n.qaSalesConsultant;
    case 'training':
      return l10n.qaTraining;
    case 'wallet':
      return l10n.qaWallet;
    case 'support_tickets':
      return l10n.qaSupportTickets;
    case 'quotes':
      return l10n.qaQuotes;
    case 'dealer_visits':
      return l10n.qaDealerVisits;
    default:
      return action.label;
  }
}

class QuickActionsOrder {
  /// Kayıtlı sıralamayı okuyup, kAllQuickActions listesini o sıraya göre
  /// dizer. Hiç kayıt yoksa (ilk kullanım) varsayılan sıra kullanılır.
  static Future<List<QuickActionDef>> getOrdered() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIds = prefs.getStringList(_kOrderKey);
    // ÖNEMLİ: kAllQuickActions bir `const` (değiştirilemez) liste — hiç
    // kayıtlı sıralama yokken bunu doğrudan döndürüp üzerinde
    // removeAt/insert çağırmaya çalışmak sessizce başarısız oluyordu
    // (sürükleme animasyonu oynuyordu ama gerçek sıra hiç değişmiyordu).
    // Bu yüzden her zaman DEĞİŞTİRİLEBİLİR yeni bir liste döndürüyoruz.
    if (savedIds == null) return List<QuickActionDef>.from(kAllQuickActions);

    final byId = {for (final a in kAllQuickActions) a.id: a};
    final ordered = <QuickActionDef>[];
    for (final id in savedIds) {
      final action = byId.remove(id);
      if (action != null) ordered.add(action);
    }
    // Kayıttan sonra listeye yeni öğe eklenmiş olabilir (güncelleme
    // sonrası) — onları da sona ekleyelim ki kaybolmasınlar.
    ordered.addAll(byId.values);
    return ordered;
  }

  static Future<void> save(List<QuickActionDef> order) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kOrderKey, order.map((a) => a.id).toList());
  }
}
