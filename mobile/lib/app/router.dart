import 'package:go_router/go_router.dart';
import 'dart:io';
import '../features/splash/splash_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/home/home_screen.dart';
import '../features/ai_assistant/ai_chat_screen.dart';
import '../features/sales/sales_consultants_screen.dart';
import '../features/training/training_center_screen.dart';
import '../features/wallet/document_wallet_screen.dart';
import '../features/support_tickets/support_tickets_screen.dart';
import '../features/quotes/quotes_screen.dart';
import '../features/messages/conversations_screen.dart';
import '../features/messages/chat_thread_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/documents/document_viewer_screen.dart';
import '../features/documents/barcode_scanner_screen.dart';
import '../features/team/team_screen.dart';
import '../features/maintenance/maintenance_screen.dart';
import '../features/bom/bom_builder_screen.dart';
import '../features/home/reorder_quick_actions_screen.dart';
import '../features/profile/specialty_screen.dart';
import '../features/profile/year_in_review_screen.dart';
import '../features/legal/about_us_screen.dart';
import '../features/legal/kvkk_screen.dart';
import '../features/appointments/appointments_screen.dart';
import '../features/search/search_screen.dart';
import '../features/favorites/favorites_screen.dart';
import '../features/groups/groups_screen.dart';
import '../features/community/community_screen.dart';
import '../features/community/community_post_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/dealers/blocked_users_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/calculators/calculators_screen.dart';
import '../features/announcements/announcements_screen.dart';
import '../features/documents/offline_documents_screen.dart';
import '../features/commissioning/commissioning_screen.dart';
import '../features/dealer_visits/dealer_visits_screen.dart';
import 'root_shell.dart';

final appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
    GoRoute(
      path: '/documents/:documentId',
      builder: (context, state) => DocumentViewerScreen(
        documentId: state.pathParameters['documentId']!,
        page: int.tryParse(state.uri.queryParameters['page'] ?? ''),
      ),
    ),
    // ÖNEMLİ DÜZELTME: "key reservation contains key" hatası — bu rota
    // daha önce (alt menünün sabit kalması için) /ai şubesinin İÇİNE,
    // iç içe (nested) bir rota olarak taşınmıştı. Bu, go_router'ın
    // StatefulShellRoute + iç içe rota kombinasyonunda GlobalKey
    // çakışmasına yol açtı ve uygulama çöktü. Kararlılık, alt menünün
    // bu tek ekranda sabit kalmasından DAHA ÖNEMLİ — bu yüzden eski,
    // kanıtlanmış (şemanın dışında, en üst seviye) haline geri alındı.
    GoRoute(
      path: '/ai/conversation/:id',
      builder: (context, state) => AiChatScreen(conversationId: state.pathParameters['id']),
    ),
    GoRoute(
      path: '/chat/:conversationId',
      builder: (context, state) => ChatThreadScreen(conversationId: state.pathParameters['conversationId']!),
    ),
    GoRoute(path: '/about', builder: (context, state) => const AboutUsScreen()),
    GoRoute(path: '/kvkk', builder: (context, state) => const KvkkScreen()),
    GoRoute(path: '/appointments', builder: (context, state) => const AppointmentsScreen()),
    GoRoute(path: '/search', builder: (context, state) => const SearchScreen()),
    GoRoute(path: '/favorites', builder: (context, state) => const FavoritesScreen()),
    GoRoute(path: '/groups', builder: (context, state) => const GroupsScreen()),
    GoRoute(path: '/community', builder: (context, state) => const CommunityScreen()),
    GoRoute(
      path: '/community/:postId',
      builder: (context, state) => CommunityPostScreen(postId: state.pathParameters['postId']!),
    ),
    GoRoute(path: '/notifications', builder: (context, state) => const NotificationsScreen()),
    GoRoute(path: '/blocked-users', builder: (context, state) => const BlockedUsersScreen()),
    GoRoute(path: '/sales-consultants', builder: (context, state) => const SalesConsultantsScreen()),
    GoRoute(path: '/training', builder: (context, state) => const TrainingCenterScreen()),
    GoRoute(path: '/wallet', builder: (context, state) => const DocumentWalletScreen()),
    GoRoute(path: '/support-tickets', builder: (context, state) => const SupportTicketsScreen()),
    GoRoute(path: '/quotes', builder: (context, state) => const QuotesScreen()),
    GoRoute(path: '/dealer-visits', builder: (context, state) => const DealerVisitsScreen()),
    GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
    GoRoute(path: '/barcode-scanner', builder: (context, state) => const BarcodeScannerScreen()),
    GoRoute(path: '/team', builder: (context, state) => const TeamScreen()),
    GoRoute(path: '/maintenance', builder: (context, state) => const MaintenanceScreen()),
    GoRoute(path: '/bom-builder', builder: (context, state) => const BomListScreen()),
    GoRoute(path: '/reorder-quick-actions', builder: (context, state) => const ReorderQuickActionsScreen()),
    GoRoute(path: '/specialty', builder: (context, state) => const SpecialtyScreen()),
    GoRoute(path: '/year-in-review', builder: (context, state) => const YearInReviewScreen()),
    GoRoute(path: '/calculators', builder: (context, state) => const CalculatorsScreen()),
    GoRoute(path: '/announcements', builder: (context, state) => const AnnouncementsScreen()),
    GoRoute(path: '/offline-documents', builder: (context, state) => const OfflineDocumentsScreen()),
    GoRoute(path: '/commissioning', builder: (context, state) => const CommissioningListScreen()),
    // Ana Sayfa'daki "AI'a Sor" kısayolu için: alt sekmeye geçiş
    // (context.go) yerine push ile açılan, geri okuyla dönülebilen ayrı
    // bir rota. Bottom nav'daki "/ai" sekmesiyle aynı sürekli sohbeti
    // gösterir.
    GoRoute(path: '/ai-quick', builder: (context, state) => const AiChatScreen()),
    // "Fotoğraf Gönder" kısayolu — önceden bu, kamera içermeyen liste
    // ekranına (AiAssistantScreen) gidiyordu, tıklamanın hiçbir etkisi
    // yokmuş gibi görünüyordu. Artık doğrudan kamerayı otomatik açan bir
    // AI sohbeti başlatıyor.
    GoRoute(path: '/ai-photo', builder: (context, state) => const AiChatScreen(autoOpenCamera: true)),
    // Ana Sayfa'nın üst kutusundan doğrudan soru/fotoğraf gönderildiğinde
    // kullanılır — state.extra ile soru metni ve/veya fotoğraf dosyası taşınır.
    GoRoute(
      path: '/ai-send',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return AiChatScreen(
          initialQuestion: extra?['question'] as String?,
          initialImage: extra?['image'] as File?,
        );
      },
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => RootShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (c, s) => const HomeScreen())]),
        // ÖNEMLİ DÜZELTME: Kullanıcı isteği: "AI Teknik Asistan'a
        // basınca içine sürekli yazabileyim, her yeni soruda kart
        // açmasın." Önceden bu sekme, ayrı bir "önizleme" ekranı
        // (AiAssistantScreen) gösterip oradan sohbete GEÇİŞ yapıyordu
        // — artık sekmenin kendisi doğrudan sürekli sohbet ekranı
        // (AiChatScreen). Ayrı bir ekrana gitmediği için önceki
        // "key reservation" çökmesi de bir daha yaşanmaz.
        StatefulShellBranch(routes: [GoRoute(path: '/ai', builder: (c, s) => const AiChatScreen())]),
        StatefulShellBranch(routes: [GoRoute(path: '/messages', builder: (c, s) => const ConversationsScreen())]),
        StatefulShellBranch(routes: [GoRoute(path: '/profile', builder: (c, s) => const ProfileScreen())]),
      ],
    ),
  ],
);
