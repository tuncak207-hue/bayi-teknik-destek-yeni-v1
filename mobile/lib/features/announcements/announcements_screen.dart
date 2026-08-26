import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_components.dart';
import '../../core/widgets/design_system.dart';
import '../../core/events/notification_badge_bus.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final Dio _dio = ApiClient().dio;
  List<dynamic> _announcements = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _dio.post('/notifications/mark-type-read/announcement').then((_) => NotificationBadgeBus.bump());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _dio.get('/announcements/mine');
    setState(() {
      _announcements = res.data;
      _loading = false;
    });
  }

  Future<void> _openDetail(dynamic announcement) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => _AnnouncementDetailScreen(announcement: announcement)),
    );
    // Detaydan her dönüşte tazele — hem "kaldırma" hem "okundu" durumu
    // değişmiş olabilir, kart görünümü güncel kalmalı.
    _load();
  }

  String _formatDate(String? iso) {
    final d = DateTime.tryParse(iso ?? '');
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.navy),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Duyurular',
                    style: AppText.screenTitle,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _announcements.isEmpty
                    ? RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          children: [
                            const SizedBox(height: 60),
                            const AppEmptyState(icon: Icons.campaign_outlined, title: 'Henüz bir duyuru yok'),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          itemCount: _announcements.length,
                          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
                          itemBuilder: (context, index) {
                      final a = _announcements[index];
                      final isCritical = a['isCritical'] == true;
                      final isUnread = a['isRead'] != true;
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: isUnread
                              ? Border.all(color: AppColors.brand.withValues(alpha: 0.5), width: 1.5)
                              : (isCritical ? Border.all(color: AppColors.brand.withValues(alpha: 0.3)) : null),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 2))],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _openDetail(a),
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: (isCritical ? AppColors.brand : AppColors.navy).withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      isCritical ? Icons.warning_amber_rounded : Icons.campaign_outlined,
                                      color: isCritical ? AppColors.brand : AppColors.navy,
                                      size: 19,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                a['title'] ?? '',
                                                style: TextStyle(fontWeight: isUnread ? FontWeight.w800 : FontWeight.w700, fontSize: 14.5),
                                              ),
                                            ),
                                            if (isUnread)
                                              Container(
                                                margin: const EdgeInsets.only(left: 6),
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                decoration: BoxDecoration(color: AppColors.brand, borderRadius: BorderRadius.circular(20)),
                                                child: const Text('YENİ', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Colors.white)),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          a['body'] ?? '',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500, height: 1.3),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(_formatDate(a['createdAt']), style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.chevron_right, color: Colors.grey.shade300),
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
}

class _AnnouncementDetailScreen extends StatefulWidget {
  final dynamic announcement;
  const _AnnouncementDetailScreen({required this.announcement});

  @override
  State<_AnnouncementDetailScreen> createState() => _AnnouncementDetailScreenState();
}

class _AnnouncementDetailScreenState extends State<_AnnouncementDetailScreen> {
  final Dio _dio = ApiClient().dio;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    // Duyuru açılınca okundu olarak işaretlenir — kart üzerindeki "YENİ"
    // belirginliği bu sayede kalkar.
    _dio.post('/announcements/${widget.announcement['id']}/mark-read');
  }

  Future<void> _dismiss() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Duyuruyu Kaldır'),
        content: const Text('Bu duyuru kendi listenizden kaldırılacak. Emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Kaldır', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _dismissing = true);
    try {
      await _dio.delete('/announcements/${widget.announcement['id']}/dismiss');
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _dismissing = false);
    }
  }

  String _formatDate(String? iso) {
    final d = DateTime.tryParse(iso ?? '');
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}  ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.announcement;
    final isCritical = a['isCritical'] == true;
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppPageHeader(
        title: 'Duyuru',
        actions: [
          IconButton(
            icon: _dismissing
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.delete_outline),
            tooltip: 'Kaldır',
            onPressed: _dismissing ? null : _dismiss,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: isCritical ? Border.all(color: AppColors.brand.withValues(alpha: 0.3)) : null,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 12, offset: const Offset(0, 3))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: (isCritical ? AppColors.brand : AppColors.navy).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        isCritical ? Icons.warning_amber_rounded : Icons.campaign_outlined,
                        color: isCritical ? AppColors.brand : AppColors.navy,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.navy)),
                          const SizedBox(height: 2),
                          Text(_formatDate(a['createdAt']), style: TextStyle(fontSize: 11.5, color: Colors.grey.shade400)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(a['body'] ?? '', style: const TextStyle(fontSize: 14, height: 1.6)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
