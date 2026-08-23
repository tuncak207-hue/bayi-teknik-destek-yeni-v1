import 'package:flutter/material.dart';

/// Kullanıcı isteği: "Uygulamanın tamamında Android ve iOS dahil olmak
/// üzere TEK FONT AİLESİ kullan: Inter. Sistem fontuna (Roboto/SF Pro)
/// geçiş yapma." Önceki platforma-göre-değişen font mantığı tamamen
/// kaldırıldı — artık hem Android hem iOS'ta, pubspec.yaml'da gömülü
/// gerçek Inter font dosyaları (400/500/600/700/800 ağırlıkları)
/// kullanılıyor.
const String _platformFontFamily = 'Inter';

/// KOMPLE YENİ TASARIM SİSTEMİ — Kullanıcı isteği: "Trendyol Satıcı Paneli
/// gibi bir tasarım istiyorum... komple yeni bir tasarım... kart tipleri,
/// menüler, her şeyi değiştir, hiçbir şey eskisi gibi olmamalı."
///
/// Önceki lacivert/bordo kurumsal palet TAMAMEN terk edildi. Yeni palet:
/// sıcak turuncu (canlı, güven veren, e-ticaret/satıcı paneli dilinde
/// yaygın) + koyu antrasit nötrler (lacivert yerine). Bu iki değer,
/// uygulamanın YÜZLERCE dosyasında `AppColors.brand`/`AppColors.navy`
/// olarak referans alındığı için, SADECE burada değiştirmek bile
/// otomatik olarak geniş bir görsel dönüşüm sağlıyor.
class AppColors {
  // ---- Ana marka renkleri (turuncu + antrasit) ----
  static const brand = Color(0xFFE8590C);
  static const brandDark = Color(0xFFB8450A);
  static const brandLight = Color(0xFFFDEDE3);
  static const navy = Color(0xFF1C1D21);
  static const navyLight = Color(0xFF3A3D45);
  static const ink = Color(0xFF1C1D21);
  // Kullanıcı isteği: "Ana background çok hafif kırık beyaz/off-white
  // olabilir. Kartlar beyaz kalabilir." Ekranın tamamen düz beyaz
  // görünmesi azaltıldı — çok hafif, göze zor görünecek kadar ince bir
  // fark bırakıldı (surface hierarchy).
  static const surface = Color(0xFFFAFAF9);
  static const success = Color(0xFF1B8A5A);
  static const warning = Color(0xFFB8450A);
  static const danger = Color(0xFFD92D20);
  static const divider = Color(0xFFEBEBED);

  // ---- Semantik tasarım sistemi katmanı ----
  static const primary = brand;
  // Kullanıcı isteği: "AppColors.primarySoft" — turuncunun çok açık,
  // arka plan/soft-container amaçlı tonu.
  static const primarySoft = Color(0xFFFDEDE3);
  static const primaryContainer = primarySoft;
  static const onPrimary = Colors.white;
  static const secondary = navy;
  static const secondaryContainer = Color(0xFFEDEDEF);
  static const onSecondary = Colors.white;

  static const background = surface;
  static const surfaceBase = Colors.white;
  // Kullanıcı isteği: "AppColors.surfaceSecondary" — kartlardan bir
  // ton daha soluk, hafif sıcak bir ikincil yüzey (örn. istatistik
  // kartlarının arka planı, soft icon container'lar için).
  static const surfaceSecondary = Color(0xFFF6F3F1);
  static const surfaceVariant = Color(0xFFF7F7F8);
  static const outline = Color(0xFFEBEBED);
  static const outlineStrong = Color(0xFFD8D8DC);
  // Kullanıcı isteği: "AppColors.border" — kartlarda artık kenarlık
  // yerine gölge kullanılıyor, ama gerektiğinde (örn. input alanları)
  // kullanılacak çok hafif bir kenarlık tonu.
  static const border = Color(0xFFEEEEEC);

  static const textPrimary = Color(0xFF1C1D21);
  static const textSecondary = Color(0xFF5C5E66);
  static const textMuted = Color(0xFF9A9CA5);
  static const textOnDark = Colors.white;

  static const successColor = Color(0xFF1B8A5A);
  static const successContainer = Color(0xFFE5F6ED);
  static const warningColor = Color(0xFFB8450A);
  static const warningContainer = Color(0xFFFDEDE3);
  static const errorColor = Color(0xFFD92D20);
  static const errorContainer = Color(0xFFFCE8E6);
  static const infoColor = Color(0xFF0E63B0);
  static const infoContainer = Color(0xFFE7F1FB);
}

/// Kullanıcı isteği: "8px tabanlı spacing sistemi kullan."
class AppSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 40.0;
  // Geriye uyumluluk için eski isimler korundu.
  static const radius = 12.0;
  static const radiusLg = 18.0;
}

/// Kullanıcı isteği: "Şu anda tasarımda her şey fazla yuvarlak... Her
/// şeyi pill şeklinde yapma." Belirtilen aralıklara göre kalibre edildi:
/// büyük banner 20-24px, normal kart 16-18px, küçük component 10-14px,
/// buton 12-16px.
class AppRadius {
  static const sm = 12.0; // küçük component
  static const md = 16.0; // buton / normal kart
  static const lg = 18.0; // normal kart (üst sınır)
  static const xl = 22.0; // büyük banner
  static const pill = 999.0;
}

/// Kullanıcı isteği: "Shadow kullan ama çok hafif... Amaç: subtle
/// elevation. Kartlar ne tamamen düz ne de ağır gölgeli olmalı." —
/// önceki "hiç gölge yok" kararı geri alındı, kontrollü, çok hafif
/// gölgeler geri getirildi.
class AppShadows {
  static List<BoxShadow> subtle = [
    BoxShadow(color: Colors.black.withOpacity(0.035), blurRadius: 8, offset: const Offset(0, 2)),
  ];
  static List<BoxShadow> card = [
    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 14, offset: const Offset(0, 4)),
  ];
  static List<BoxShadow> elevated = [
    BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 22, offset: const Offset(0, 8)),
  ];
}

/// Kullanıcı isteği: "daha global daha premium olmalı, büyük uygulamaların
/// yazı formatını baz alabilirsin." Uygulamanın dört bir yanında sabit
/// (hardcoded) TextStyle'lar kullanılıyordu, merkezi temaya hiç bağlı
/// değillerdi — bu yüzden merkezi textTheme'i güncellemek tek başına
/// yeterli olmuyordu. Burada, Stripe/Linear/Apple tarzı büyük
/// uygulamalarda görülen dile (sıkı harf aralığı büyük başlıklarda, güçlü
/// ağırlık kontrastı, bol nefes payı) uygun, HER YERDE elle çağrılabilecek
/// sabit stiller tanımlanıyor. Ekranlar bunları kullanmaya geçtikçe
/// tutarlı, premium bir görünüm yayılacak.
class AppText {
  // Ekran/bölüm başlıkları — büyük, kalın, sıkı harf aralığı.
  static const screenTitle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: AppColors.navy,
    letterSpacing: -0.4,
    height: 1.2,
  );
  // Kart/bölüm içi alt başlıklar (örn. "Sabitlenmiş Dokümanlar").
  static const sectionTitle = TextStyle(
    fontSize: 15.5,
    fontWeight: FontWeight.w700,
    color: AppColors.navy,
    letterSpacing: -0.2,
  );
  // Küçük, büyük harf etiketler (örn. "BU AY", kategori rozetleri).
  static const eyebrow = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: Color(0xFF6B7684),
    letterSpacing: 0.6,
  );
  // Öne çıkan büyük rakam/istatistik (örn. "12" ziyaret sayısı).
  static const statValue = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w900,
    color: AppColors.navy,
    letterSpacing: -0.8,
    height: 1,
  );
  static const statLabel = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: Color(0xFF6B7684),
    height: 1.3,
  );
  // Gövde metni — normal okuma metni.
  static const body = TextStyle(
    fontSize: 14.5,
    fontWeight: FontWeight.w400,
    color: AppColors.ink,
    height: 1.45,
    letterSpacing: -0.1,
  );
  static const bodyStrong = TextStyle(
    fontSize: 14.5,
    fontWeight: FontWeight.w600,
    color: AppColors.navy,
    letterSpacing: -0.1,
  );
  static const caption = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    color: Color(0xFF8A93A0),
    height: 1.3,
  );
}

class AppTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      fontFamily: _platformFontFamily,
      scaffoldBackgroundColor: AppColors.surface,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brand,
        brightness: Brightness.light,
        primary: AppColors.brand,
        secondary: AppColors.navy,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        // Kullanıcı isteği: "hiç bir şeyde gölge olmayacak" — AppBar'ın
        // gölgesi de tamamen kaldırıldı.
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        // ÖNEMLİ DÜZELTME: "Bayilere Sor gibi ekranlarda başlık Status
        // Bar'a çok yakın, bunu Ana Sayfa'da yaptığımız gibi tüm
        // ekranlara uygula." Standart AppBar kullanan HER ekran (Bayilere
        // Sor dahil, ~40 ekran) buradan besleniyor — merkezi olarak
        // yükseklik artırılıp nefes payı eklendi, tek tek ekran
        // değiştirmeye gerek kalmadı.
        toolbarHeight: 76,
        titleTextStyle: TextStyle(
          fontFamily: _platformFontFamily,
          color: AppColors.navy,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
        iconTheme: IconThemeData(color: AppColors.navy),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          // KOMPLE YENİ TASARIM: Ana buton artık marka rengiyle (turuncu),
          // önceki koyu antrasit yerine — e-ticaret/satıcı paneli
          // dilinde birincil eylem butonu hep marka renginde olur.
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          textStyle: TextStyle(fontFamily: _platformFontFamily, fontWeight: FontWeight.w700, letterSpacing: 0.3, fontSize: 15),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.navy,
          side: const BorderSide(color: AppColors.navy, width: 1.4),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radius)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radius),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radius),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radius),
          borderSide: const BorderSide(color: AppColors.brand, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
      cardTheme: CardThemeData(
        elevation: 3,
        shadowColor: AppColors.navy.withOpacity(0.10),
        color: Colors.white,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: const BorderSide(color: AppColors.divider),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 0,
        indicatorColor: AppColors.primary.withOpacity(0.12),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: _platformFontFamily,
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w600,
            letterSpacing: 0.1,
            color: states.contains(WidgetState.selected) ? AppColors.primary : AppColors.textMuted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? AppColors.primary : AppColors.textMuted,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.divider, thickness: 1),
      // Kullanıcı isteği: "tüm o küçük onay pencereleri için değiştir" —
      // AlertDialog/showDialog kullanan HER yer (silme onayları, çıkış
      // onayı, randevu/rapor sil vb.) bu merkezi ayarı otomatik alır.
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        titleTextStyle: TextStyle(
          fontFamily: _platformFontFamily,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.navy,
        ),
        contentTextStyle: TextStyle(
          fontFamily: _platformFontFamily,
          fontSize: 14,
          color: AppColors.ink.withOpacity(0.75),
          height: 1.4,
        ),
      ),
      // Kullanıcı isteği: "tüm hepsinde güncelle" — PopupMenuButton
      // kullanan HER yer (PDF Görüntüle/Paylaş menüleri, Teknik Destek
      // durum menüleri vb.) bu merkezi ayarı otomatik alır.
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radius),
          side: BorderSide(color: Colors.grey.shade100),
        ),
        textStyle: TextStyle(
          fontFamily: _platformFontFamily,
          fontSize: 14,
          color: AppColors.ink,
          fontWeight: FontWeight.w500,
        ),
      ),
      // Kullanıcı isteği: "il ilçe tarih saat seçerken arka fon beyaz
      // olmalı" — showDatePicker/showTimePicker'ın kendi arka planı ve
      // il/ilçe gibi dropdown menülerin açılır listesi buradan
      // merkezi olarak beyaza sabitlendi.
      canvasColor: Colors.white,
      datePickerTheme: DatePickerThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        headerBackgroundColor: AppColors.navy,
        headerForegroundColor: Colors.white,
        todayBackgroundColor: WidgetStateProperty.all(AppColors.brand.withOpacity(0.1)),
        todayForegroundColor: WidgetStateProperty.all(AppColors.brand),
        dayForegroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? Colors.white : AppColors.ink,
        ),
        dayBackgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.brand : null,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusLg)),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: Colors.white,
        dialBackgroundColor: Colors.grey.shade50,
        dialHandColor: AppColors.brand,
        hourMinuteColor: Colors.grey.shade50,
        hourMinuteTextColor: AppColors.navy,
        dayPeriodColor: Colors.grey.shade50,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusLg)),
      ),
      // Kullanıcı isteği: "bu seçim penceresini de uyumlu yap, arka plan
      // beyaz olsun" — showModalBottomSheet kullanan HER yer (Kamera/
      // Galeri seçimi, diğer alttan açılan seçim pencereleri) bu merkezi
      // ayarı otomatik alır.
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        modalBackgroundColor: Colors.white,
        elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
        ),
      ),
      // Kullanıcı isteği: "Font boyutları, ağırlıkları ve satır aralıkları
      // platform standartlarına uygun olsun. Başlıklar için semibold/bold,
      // normal metinler için regular/medium kullan." — tüm ölçek burada
      // tanımlı; renkler öncekiyle birebir aynı, sadece boyut/ağırlık/
      // satır aralığı ve font ailesi düzenlendi.
      textTheme: TextTheme(
        displayLarge: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: AppColors.navy, height: 1.15, letterSpacing: 0.2),
        displayMedium: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.navy, height: 1.18),
        displaySmall: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.navy, height: 1.2),
        headlineLarge: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.navy, height: 1.2),
        headlineMedium: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.navy, height: 1.22),
        headlineSmall: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.navy, height: 1.25, letterSpacing: 0.1),
        titleLarge: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.navy, height: 1.25),
        titleMedium: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink, height: 1.3),
        titleSmall: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.ink, height: 1.3),
        bodyLarge: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.ink, height: 1.45),
        bodyMedium: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w400, color: AppColors.ink, height: 1.4),
        bodySmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: AppColors.ink.withOpacity(0.72), height: 1.35),
        labelLarge: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.ink, height: 1.3, letterSpacing: 0.1),
        labelMedium: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: AppColors.ink, height: 1.3),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.ink.withOpacity(0.65), height: 1.3, letterSpacing: 0.2),
      ),
    );
  }

  static ThemeData dark() {
    const darkSurface = Color(0xFF0F1720);
    const darkCard = Color(0xFF17222E);
    return ThemeData(
      useMaterial3: true,
      fontFamily: _platformFontFamily,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkSurface,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brand,
        brightness: Brightness.dark,
        primary: const Color(0xFFE05A6E), // koyu temada daha açık, okunabilir bordo tonu
        secondary: AppColors.navyLight,
        surface: darkCard,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: darkCard,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 76,
        titleTextStyle: TextStyle(fontFamily: _platformFontFamily, color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
      ),
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE05A6E),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radius)),
          textStyle: TextStyle(fontFamily: _platformFontFamily, fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radius),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkCard,
        elevation: 0,
        indicatorColor: Colors.white.withOpacity(0.08),
        labelTextStyle: WidgetStateProperty.all(
          TextStyle(fontFamily: _platformFontFamily, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.1),
        ),
      ),
      dividerTheme: DividerThemeData(color: Colors.white.withOpacity(0.08), thickness: 1),
      dialogTheme: DialogThemeData(
        backgroundColor: darkCard,
        surfaceTintColor: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        titleTextStyle: TextStyle(
          fontFamily: _platformFontFamily,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        contentTextStyle: TextStyle(
          fontFamily: _platformFontFamily,
          fontSize: 14,
          color: Colors.white.withOpacity(0.75),
          height: 1.4,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: darkCard,
        surfaceTintColor: darkCard,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radius),
          side: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        textStyle: TextStyle(
          fontFamily: _platformFontFamily,
          fontSize: 14,
          color: Colors.white.withOpacity(0.9),
          fontWeight: FontWeight.w500,
        ),
      ),
      textTheme: TextTheme(
        displayLarge: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: Colors.white, height: 1.15, letterSpacing: 0.2),
        displayMedium: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white, height: 1.18),
        displaySmall: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white, height: 1.2),
        headlineLarge: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white, height: 1.2),
        headlineMedium: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white, height: 1.22),
        headlineSmall: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white, height: 1.25, letterSpacing: 0.1),
        titleLarge: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white, height: 1.25),
        titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.92), height: 1.3),
        titleSmall: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.92), height: 1.3),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: Colors.white.withOpacity(0.87), height: 1.45),
        bodyMedium: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w400, color: Colors.white.withOpacity(0.87), height: 1.4),
        bodySmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: Colors.white.withOpacity(0.65), height: 1.35),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white.withOpacity(0.87), height: 1.3, letterSpacing: 0.1),
        labelMedium: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: Colors.white.withOpacity(0.87), height: 1.3),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.white.withOpacity(0.6), height: 1.3, letterSpacing: 0.2),
      ),
    );
  }
}
