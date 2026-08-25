import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'dart:async';
import '../../core/api/api_client.dart';
import '../../core/api/socket_service.dart';
import '../../core/notifications/notification_sound_service.dart';
import '../../core/auth/current_user.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/empty_state.dart';
class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  final Dio _dio = ApiClient().dio;
  final _searchController = TextEditingController();
  List<dynamic> _conversations = [];
  Set<String> _unreadIds = {};
  bool _loading = true;
  StreamSubscription<Map<String, dynamic>>? _messageSub;

  List<dynamic>? _searchResults;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _load();
    // ÖNEMLİ: Önceden bu ekranın hiç gerçek zamanlı (soket) dinleyicisi
    // yoktu — siz Mesajlar ekranındayken yeni bir mesaj gelse bile liste
    // güncellenmiyordu, konuşmadan geri dönünce de yenilenmiyordu.
    // WhatsApp'ta olduğu gibi anlık güncelleme için, herhangi bir mesaj
    // geldiğinde listeyi otomatik yeniden çekiyoruz.
    SocketService().connect();
    _messageSub = SocketService().onMessage.listen((data) {
      _load();
      if (data['senderId'] != CurrentUser().id) NotificationSoundService().play();
    });
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    super.dispose();
  }

  bool _showArchived = false;

  Future<void> _load() async {
    if (!mounted) return;
    final results = await Future.wait([
      _dio.get('/chat/conversations', queryParameters: {'archived': _showArchived}),
      _dio.get('/notifications/unread-conversation-ids'),
    ]);
    if (!mounted) return;
    setState(() {
      // Mesajlar sekmesi SADECE kişiler arası özel (DIRECT) bayi-bayi
      // mesajlarını gösterir. Satış danışmanlarıyla olan yazışmalar
      // (role == SALES) BAYİ için burada GÖRÜNMEZ — "Satış Danışmanına Sor"
      // tamamen izole bir alan olmalı. AMA bu filtre sadece bayiler için
      // geçerli olmalı: satış danışmanının KENDİSİ giriş yapıp buraya
      // baktığında, kendi gelen sorularını görebilmesi gerekiyor — önceden
      // bu filtre herkes için (danışmanın kendisi dahil) uygulanıyordu,
      // danışman hiçbir zaman gelen soruları göremiyordu.
      final iAmSalesConsultant = CurrentUser().role == 'SALES';
      _conversations = (results[0].data as List).where((c) {
        if (c['type'] != 'DIRECT') return false;
        if (iAmSalesConsultant) return true;
        final participants = c['participants'] as List? ?? [];
        final isSalesChat = participants.any((p) => p['user']?['role'] == 'SALES');
        return !isSalesChat;
      }).toList();
      _unreadIds = Set<String>.from(results[1].data['conversationIds'] ?? []);
      _loading = false;
    });
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = null);
      return;
    }
    setState(() => _searching = true);
    try {
      final res = await _dio.get('/search', queryParameters: {'q': query});
      // /search zaten sadece role=DEALER hesapları döner, satış danışmanları
      // karışmaz.
      if (mounted) setState(() => _searchResults = res.data['dealers'] ?? []);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _startChatWith(String dealerId) async {
    final res = await _dio.post('/chat/conversations/direct', data: {'otherUserId': dealerId});
    if (!mounted) return;
    _searchController.clear();
    setState(() => _searchResults = null);
    context.push('/chat/${res.data['id']}').then((_) => _load());
  }

  Future<bool> _confirmDeleteConversation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sohbeti Sil'),
        content: const Text('Bu sohbet listenizden kaldırılacak. Karşı taraf tekrar mesaj gönderirse yeniden görünür.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _deleteConversation(String conversationId) async {
    setState(() => _conversations.removeWhere((c) => c['id'] == conversationId));
    await _dio.delete('/chat/conversations/$conversationId');
  }

  /// Kullanıcı isteği: "mesajlara arşivleme ekle."
  Future<void> _archiveConversation(String conversationId) async {
    setState(() => _conversations.removeWhere((c) => c['id'] == conversationId));
    await _dio.post('/chat/conversations/$conversationId/archive');
  }

  Future<void> _unarchiveConversation(String conversationId) async {
    setState(() => _conversations.removeWhere((c) => c['id'] == conversationId));
    await _dio.post('/chat/conversations/$conversationId/unarchive');
  }

  String _titleFor(dynamic c) {
    final myId = CurrentUser().id;
    final participants = c['participants'] as List? ?? [];
    final other = participants.firstWhere(
      (p) => p['userId'] != myId,
      orElse: () => null,
    );
    if (other == null || other['user'] == null) return 'Bayi Sohbeti';
    return '${other['user']['firstName']} ${other['user']['lastName']}';
  }

  String _timeAgo(String? iso) {
    final d = DateTime.tryParse(iso ?? '');
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'şimdi';
    if (diff.inHours < 1) return '${diff.inMinutes}dk';
    if (diff.inDays < 1) return '${diff.inHours}sa';
    return '${diff.inDays}g';
  }

  @override
  Widget build(BuildContext context) {
    // Kullanıcı isteği: "tüm menü kartlarında appbar silinecek, yerine
    // Gruplar'daki gibi büyük başlık gelecek" — Mesajlar da diğer 19
    // ana menü kartıyla aynı tutarlı desene geçirildi.
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
        child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.md, AppSpacing.md, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppColors.navy),
                  onPressed: () {
                    if (Navigator.canPop(context)) Navigator.pop(context);
                  },
                ),
                Expanded(
                  child: Text(
                    _showArchived ? 'Arşivlenmiş Sohbetler' : 'Mesajlar',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.navy, letterSpacing: -0.7, height: 1.1),
                  ),
                ),
                IconButton(
                  icon: Icon(_showArchived ? Icons.chat_bubble_outline : Icons.archive_outlined),
                  tooltip: _showArchived ? 'Sohbetlere Dön' : 'Arşivi Görüntüle',
                  onPressed: () {
                    setState(() => _showArchived = !_showArchived);
                    _load();
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xs),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Bayi veya üye adı yazıp mesaj başlatın...',
                prefixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchResults = null);
                        },
                      )
                    : null,
              ),
              onChanged: _search,
            ),
          ),
          if (_searchResults != null)
            Expanded(
              child: _searchResults!.isEmpty
                  ? Center(child: Text('Bayi bulunamadı.', style: TextStyle(color: Colors.grey.shade500)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      itemCount: _searchResults!.length,
                      itemBuilder: (context, index) {
                        final d = _searchResults![index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.divider),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 3))],
                          ),
                          child: ListTile(
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [AppColors.navy.withOpacity(0.12), AppColors.brand.withOpacity(0.12)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  (d['company'] as String? ?? '?').characters.first.toUpperCase(),
                                  style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                            title: Text(d['company'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy, letterSpacing: -0.2)),
                            subtitle: Text('${d['firstName']} ${d['lastName']}', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                            trailing: const Icon(Icons.send_outlined, size: 18, color: AppColors.navy),
                            onTap: () => _startChatWith(d['id']),
                          ),
                        );
                      },
                    ),
            )
          else
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _conversations.isEmpty
                      ? RefreshIndicator(
                          onRefresh: _load,
                          child: ListView(
                            children: [
                              const SizedBox(height: 60),
                              EmptyState(
                                icon: _showArchived ? Icons.archive_outlined : Icons.chat_bubble_outline,
                                title: _showArchived ? 'Arşivlenmiş sohbet yok' : 'Henüz mesajınız yok',
                                description: _showArchived
                                    ? 'Bir sohbeti sağa kaydırarak arşive ekleyebilirsiniz.'
                                    : 'Yukarıdaki arama kutusuna bir bayi adı yazarak mesaj başlatabilirsiniz.',
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                            itemCount: _conversations.length,
                            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
                            itemBuilder: (context, index) {
                              final c = _conversations[index];
                              final messages = c['messages'] as List;
                              final lastMessage = messages.isNotEmpty ? messages[0]['content'] : 'Henüz mesaj yok';
                              final lastTime = messages.isNotEmpty ? messages[0]['createdAt'] : null;
                              final isUnread = _unreadIds.contains(c['id']);
                              return Dismissible(
                                key: ValueKey(c['id']),
                                direction: DismissDirection.horizontal,
                                confirmDismiss: (direction) async {
                                  if (direction == DismissDirection.endToStart) return _confirmDeleteConversation();
                                  return true; // startToEnd: arşivle/arşivden çıkar, onay gerekmiyor
                                },
                                onDismissed: (direction) {
                                  if (direction == DismissDirection.endToStart) {
                                    _deleteConversation(c['id']);
                                  } else {
                                    _showArchived ? _unarchiveConversation(c['id']) : _archiveConversation(c['id']);
                                  }
                                },
                                secondaryBackground: Container(
                                  decoration: BoxDecoration(color: Colors.red.shade400, borderRadius: BorderRadius.circular(16)),
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  child: const Icon(Icons.delete_outline, color: Colors.white),
                                ),
                                background: Container(
                                  decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(16)),
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.only(left: 20),
                                  child: Icon(_showArchived ? Icons.unarchive_outlined : Icons.archive_outlined, color: Colors.white),
                                ),
                                child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppColors.divider),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 3)),
                                  ],
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
                                  leading: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [AppColors.navy.withOpacity(0.12), AppColors.brand.withOpacity(0.12)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.person_outline, color: AppColors.navy),
                                      ),
                                      if (isUnread)
                                        Positioned(
                                          top: -2,
                                          right: -2,
                                          child: Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              color: AppColors.brand,
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.white, width: 2),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  title: Text(
                                    _titleFor(c),
                                    style: TextStyle(
                                      fontWeight: isUnread ? FontWeight.w800 : FontWeight.w700,
                                      fontSize: 15,
                                      color: AppColors.navy,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  subtitle: Text(
                                    lastMessage,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                                      color: isUnread ? AppColors.ink : Colors.grey.shade500,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      if (lastTime != null)
                                        Text(
                                          _timeAgo(lastTime),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isUnread ? AppColors.brand : Colors.grey.shade400,
                                            fontWeight: isUnread ? FontWeight.w700 : FontWeight.normal,
                                          ),
                                        ),
                                      const SizedBox(height: 4),
                                      Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade300),
                                    ],
                                  ),
                                  onTap: () async {
                                    if (isUnread) {
                                      setState(() => _unreadIds.remove(c['id']));
                                      _dio.post('/notifications/mark-conversation-read/${c['id']}');
                                    }
                                    if (context.mounted) {
                                      // Önceden buradan dönünce liste hiç
                                      // yenilenmiyordu — sohbette yeni
                                      // mesaj yazsanız bile Mesajlar
                                      // listesindeki önizleme eski kalıyordu.
                                      await context.push('/chat/${c['id']}');
                                      _load();
                                    }
                                  },
                                ),
                                ),
                              );
                            },
                          ),
                        ),
            ),
        ],
      ),
      ),
    );
  }
}
