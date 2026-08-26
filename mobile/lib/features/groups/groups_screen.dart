import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/design_system.dart';
import '../../core/widgets/app_components.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final Dio _dio = ApiClient().dio;
  List<dynamic> _groups = [];
  bool _loading = true;
  final Set<String> _opening = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _dio.get('/groups');
    setState(() {
      _groups = (res.data as List).where((g) => g['name'] != 'Genel Sohbet').toList();
      _loading = false;
    });
  }

  bool _isMember(dynamic group) {
    final members = group['members'] as List? ?? [];
    return members.isNotEmpty;
  }

  Future<void> _join(String groupId) async {
    await _dio.post('/groups/$groupId/join');
    _load();
  }

  Future<void> _leave(String groupId, String groupName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Gruptan Ayrıl'),
        content: Text('"$groupName" grubundan ayrılmak istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Ayrıl', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _dio.post('/groups/$groupId/leave');
    _load();
  }

  /// Önceden bu, listeden gelen (bazen eksik/eski) "conversation" alanına
  /// güveniyordu — bir grubun konuşma kaydı eksikse tıklamanın hiçbir
  /// etkisi olmuyordu ("katıldım ama giremiyorum" sorunu). Artık backend'in
  /// kendi kendini onaran uç noktasını (GET /groups/:id/conversation)
  /// çağırıyoruz — konuşma yoksa orada oluşturuluyor, burada asla boşa
  /// düşmüyoruz.
  Future<void> _openGroupChat(dynamic group) async {
    final groupId = group['id'];
    if (_opening.contains(groupId)) return;
    setState(() => _opening.add(groupId));
    try {
      final res = await _dio.get('/groups/$groupId/conversation');
      final conversationId = res.data['id'];
      if (!mounted) return;
      if (conversationId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bu grubun sohbeti açılamadı, lütfen tekrar deneyin.')),
        );
        return;
      }
      context.push('/chat/$conversationId');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sohbet açılamadı, internet bağlantınızı kontrol edin.')),
        );
      }
    } finally {
      if (mounted) setState(() => _opening.remove(groupId));
    }
  }

  IconData _iconFor(String name) {
    final n = name.toLowerCase();
    if (n.contains('yangın')) return Icons.local_fire_department_outlined;
    if (n.contains('kamera')) return Icons.videocam_outlined;
    if (n.contains('teknik')) return Icons.build_outlined;
    return Icons.groups_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppPageHeader(title: 'Gruplar'),
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _groups.isEmpty
                    ? AppEmptyState(icon: Icons.groups_2_outlined, title: 'Henüz oluşturulmuş bir grup yok')
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: CustomScrollView(
                          slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        sliver: SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: AppSpacing.sm,
                            crossAxisSpacing: AppSpacing.sm,
                            childAspectRatio: 0.95,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                      final g = _groups[index];
                      final isMember = _isMember(g);
                      final memberCount = g['_count']?['members'] ?? 0;
                      final isOpening = _opening.contains(g['id']);

                      return InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: isMember ? () => _openGroupChat(g) : () => _join(g['id']),
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 2))],
                            border: isMember ? Border.all(color: AppColors.brand.withValues(alpha: 0.15)) : null,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: (isMember ? AppColors.brand : AppColors.navy).withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: isOpening
                                        ? const Padding(
                                            padding: EdgeInsets.all(10),
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : Icon(_iconFor(g['name'] ?? ''), color: isMember ? AppColors.brand : AppColors.navy, size: 19),
                                  ),
                                  if (isMember)
                                    PopupMenuButton<String>(
                                      icon: Icon(Icons.more_vert, size: 18, color: Colors.grey.shade400),
                                      onSelected: (value) {
                                        if (value == 'leave') _leave(g['id'], g['name'] ?? '');
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(value: 'leave', child: Text('Ayrıl', style: TextStyle(color: Colors.red))),
                                      ],
                                    ),
                                ],
                              ),
                              const Spacer(),
                              Text(
                                g['name'] ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: AppColors.navy),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.people_outline, size: 12, color: Colors.grey.shade400),
                                  const SizedBox(width: 3),
                                  Text('$memberCount üye', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (!isMember)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 7),
                                  decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(9)),
                                  child: const Text('Katıl', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                                )
                              else
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 7),
                                  decoration: BoxDecoration(
                                    color: AppColors.brand.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: Text(
                                    'Sohbete Gir',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: AppColors.brand, fontSize: 12, fontWeight: FontWeight.w700),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                            },
                            childCount: _groups.length,
                          ),
                        ),
                      ),
                          ],
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
