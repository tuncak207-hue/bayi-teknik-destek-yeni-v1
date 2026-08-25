import 'package:flutter/material.dart';
import '../../core/widgets/design_system.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_components.dart';
import '../../core/events/dealers_refresh_bus.dart';

/// Bayi Rehberi — tüm onaylanmış bayilerin listelendiği, birine dokununca
/// özel (DIRECT) bir mesaj başlatabileceğiniz ekran. Önceden bu, "Bayiler"
/// sekmesinin kendisiydi; artık "Bayiler" sekmesi Genel Sohbet'i gösteriyor,
/// bu rehber oradan bir buton ile açılıyor.
class DealerDirectoryScreen extends StatefulWidget {
  const DealerDirectoryScreen({super.key});

  @override
  State<DealerDirectoryScreen> createState() => _DealerDirectoryScreenState();
}

class _DealerDirectoryScreenState extends State<DealerDirectoryScreen> {
  final Dio _dio = ApiClient().dio;
  List<dynamic> _dealers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    DealersRefreshBus.trigger.addListener(_load);
  }

  @override
  void dispose() {
    DealersRefreshBus.trigger.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final res = await _dio.get('/users/dealers');
    setState(() {
      _dealers = res.data;
      _loading = false;
    });
  }

  Future<void> _startChat(String dealerId) async {
    final res = await _dio.post('/chat/conversations/direct', data: {'otherUserId': dealerId});
    if (!mounted) return;
    context.push('/chat/${res.data['id']}');
  }

  Future<void> _blockDealer(String dealerId, String company) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Bayiyi Engelle'),
        content: Text('$company adlı bayiyi engellemek istediğinize emin misiniz? Artık birbirinize mesaj gönderemezsiniz.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Engelle', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _dio.post('/users/$dealerId/block');
    DealersRefreshBus.bump();
    _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$company engellendi.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: const AppPageHeader(title: 'Bayi Rehberi'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _dealers.isEmpty
              ? RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    children: [
                      const SizedBox(height: 60),
                      AppEmptyState(
                        icon: Icons.groups_outlined,
                        title: 'Henüz başka bir bayi yok',
                        description: 'Onaylanmış diğer bayiler burada listelenecek.',
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: _dealers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
                    itemBuilder: (context, index) {
                      final d = _dealers[index];
                      final company = (d['company'] as String?) ?? '';
                      final initial = company.isNotEmpty ? company.characters.first.toUpperCase() : '?';
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 2))],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
                          leading: d['avatarUrl'] != null
                              ? CircleAvatar(radius: 22, backgroundImage: NetworkImage(d['avatarUrl']))
                              : CircleAvatar(
                                  radius: 22,
                                  backgroundColor: AppColors.navy.withValues(alpha: 0.08),
                                  child: Text(initial, style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w700)),
                                ),
                          title: Text(company, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                          subtitle: Text('${d['firstName']} ${d['lastName']}', style: TextStyle(color: Colors.grey.shade500, fontSize: 12.5)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton.filled(
                                onPressed: () => _startChat(d['id']),
                                icon: const Icon(Icons.chat_bubble_outline, size: 17),
                                style: IconButton.styleFrom(
                                  backgroundColor: AppColors.navy.withValues(alpha: 0.08),
                                  foregroundColor: AppColors.navy,
                                  padding: const EdgeInsets.all(8),
                                ),
                                tooltip: 'Özel mesaj gönder',
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                                onSelected: (value) {
                                  if (value == 'block') _blockDealer(d['id'], company);
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(value: 'block', child: Text('Engelle')),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
