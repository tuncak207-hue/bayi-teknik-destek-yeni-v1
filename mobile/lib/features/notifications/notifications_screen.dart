import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/design_system.dart';
import '../../core/widgets/app_components.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final Dio _dio = ApiClient().dio;
  List<dynamic> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _dio.get('/notifications');
    setState(() {
      _notifications = res.data;
      _loading = false;
    });
  }

  Future<void> _markRead(String id) async {
    // ÖNEMLİ DÜZELTME: "bildirime tıklayınca kapanmıyor, yine bildirim
    // var uyarısı gözüküyor" — hata yakalama hiç yoktu, ağ sorununda
    // istek sessizce başarısız olup ekran hiç yenilenmiyordu. Artık
    // önce YEREL olarak (anında, beklemeden) okunmuş gösteriliyor,
    // arka planda backend'e bildiriliyor — başarısız olursa sessizce
    // yutuluyor ama en azından kullanıcı arayüzü anında tepki veriyor.
    setState(() {
      final idx = _notifications.indexWhere((n) => n['id'] == id);
      if (idx != -1) _notifications[idx]['readAt'] = DateTime.now().toIso8601String();
    });
    try {
      await _dio.patch('/notifications/$id/read');
    } catch (_) {
      // Arka planda sessizce yeniden dener gibi davranmak yerine,
      // en azından bir sonraki listelemede backend'in gerçek durumunu
      // yansıtması için _load() çağrılıyor.
    }
    _load();
  }

  /// Bildirim tipine ve içindeki 'data' bilgisine göre ilgili ekrana yönlendirir
  /// (derin bağlantı / deep link). Önce okundu işaretlenir, sonra yönlendirilir.
  Future<void> _handleTap(dynamic notification) async {
    final id = notification['id'];
    final isUnread = notification['readAt'] == null;
    if (isUnread) await _markRead(id);

    final type = notification['type'] as String? ?? '';
    final data = notification['data'] as Map<String, dynamic>? ?? {};
    if (!mounted) return;

    switch (type) {
      case 'new_message':
      case 'group_message':
        final conversationId = data['conversationId'];
        if (conversationId != null) context.push('/chat/$conversationId');
        break;
      case 'reply':
        final postId = data['postId'];
        if (postId != null) context.push('/community/$postId');
        break;
      case 'appointment_requested':
      case 'appointment_status_changed':
      case 'appointment_revised':
      case 'appointment_removed':
        context.push('/appointments');
        break;
      case 'ticket_created':
      case 'ticket_status_changed':
      case 'ticket_assigned':
      case 'ticket_escalated':
      case 'emergency_ticket':
        context.push('/support-tickets');
        break;
      case 'new_document':
        // Doküman ID'si bildirimde yoksa genel doküman aramasına yönlendir.
        context.push('/search');
        break;
      case 'new_training_content':
        context.push('/training');
        break;
      case 'certification_expiring':
        context.push('/specialty');
        break;
      case 'new_sales_message':
        final conversationId = data['conversationId'];
        if (conversationId != null) context.push('/chat/$conversationId');
        break;
      case 'announcement':
        context.push('/announcements');
        break;
      default:
        // Hesap onayı vb. — özel bir hedef yok, bildirimde kalınır.
        break;
    }
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'new_message':
        return Icons.chat_bubble_outline;
      case 'group_message':
        return Icons.groups_outlined;
      case 'reply':
        return Icons.reply_outlined;
      case 'announcement':
        return Icons.campaign_outlined;
      case 'account_approved':
        return Icons.check_circle_outline;
      case 'new_document':
        return Icons.description_outlined;
      case 'appointment_requested':
      case 'appointment_status_changed':
      case 'appointment_revised':
        return Icons.calendar_month_outlined;
      case 'appointment_removed':
        return Icons.event_busy_outlined;
      case 'ticket_created':
      case 'ticket_status_changed':
      case 'ticket_assigned':
        return Icons.build_outlined;
      case 'ticket_escalated':
        return Icons.trending_up;
      case 'emergency_ticket':
        return Icons.warning_amber_rounded;
      case 'chat_banned':
        return Icons.block_outlined;
      case 'new_training_content':
        return Icons.school_outlined;
      case 'certification_expiring':
        return Icons.workspace_premium_outlined;
      case 'new_sales_message':
        return Icons.support_agent_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Future<void> _markAllRead() async {
    await _dio.patch('/notifications/read-all');
    _load();
  }

  Future<void> _deleteNotification(String id) async {
    setState(() => _notifications.removeWhere((n) => n['id'] == id));
    await _dio.delete('/notifications/$id');
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tüm Bildirimleri Sil'),
        content: const Text('Tüm bildirimleriniz kalıcı olarak silinecek. Emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Tümünü Sil', style: TextStyle(color: AppColors.navy)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _notifications = []);
    await _dio.delete('/notifications/clear-all');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppPageHeader(title: 'Bildirimler'),
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
        child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    'Bildirimler',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.navy, letterSpacing: -0.6, height: 1.1),
                  ),
                ),
                if (_notifications.any((n) => n['readAt'] == null))
                  TextButton(
                    onPressed: _markAllRead,
                    child: const Text('Tümünü Okundu İşaretle', style: TextStyle(color: AppColors.brand, fontSize: 12.5)),
                  ),
                if (_notifications.isNotEmpty)
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'clear-all') _clearAll();
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'clear-all', child: Text('Tümünü Sil')),
                    ],
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _notifications.isEmpty
                    ? RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          children: [
                            const SizedBox(height: 60),
                            const AppEmptyState(icon: Icons.notifications_none, title: 'Henüz bir bildiriminiz yok'),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: _notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
                    itemBuilder: (context, index) {
                      final n = _notifications[index];
                      final isUnread = n['readAt'] == null;
                      return Dismissible(
                        key: ValueKey(n['id']),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) => _deleteNotification(n['id']),
                        background: Container(
                          decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(16)),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete_outline, color: Colors.white),
                        ),
                        child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _handleTap(n),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 2)),
                              ],
                              border: isUnread ? Border.all(color: AppColors.brand.withValues(alpha: 0.15)) : null,
                            ),
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    gradient: isUnread
                                        ? LinearGradient(colors: [AppColors.brand.withValues(alpha: 0.14), AppColors.navy.withValues(alpha: 0.10)])
                                        : null,
                                    color: isUnread ? null : const Color(0xFFF0F2F5),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    _iconFor(n['type'] ?? ''),
                                    color: isUnread ? AppColors.brand : Colors.grey.shade500,
                                    size: 19,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        n['title'] ?? '',
                                        style: TextStyle(
                                          fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600,
                                          fontSize: 14,
                                          color: const Color(0xFF1C1C1E),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        n['body'] ?? '',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500, height: 1.3),
                                      ),
                                      if (n['createdAt'] != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          _timeAgo(n['createdAt']),
                                          style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (isUnread)
                                  Container(
                                    margin: const EdgeInsets.only(top: 4, left: 4),
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(color: AppColors.brand, shape: BoxShape.circle),
                                  ),
                              ],
                            ),
                          ),
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

  String _timeAgo(String isoDate) {
    final date = DateTime.tryParse(isoDate);
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} sa önce';
    if (diff.inDays < 7) return '${diff.inDays} gün önce';
    return '${date.day}.${date.month}.${date.year}';
  }
}
