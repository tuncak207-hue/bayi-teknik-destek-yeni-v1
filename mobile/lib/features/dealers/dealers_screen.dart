import 'package:flutter/material.dart';
import '../../core/widgets/design_system.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_components.dart';
import '../../core/events/dealers_refresh_bus.dart';

/// Bayiler — tüm onaylanmış bayilerin listelendiği, birine dokununca özel
/// (DIRECT) bir mesaj başlatabileceğiniz ekran. Bu sohbetler Mesajlar
/// sekmesinde de görünür (aynı özel mesajlar). Genel Sohbet kaldırıldı —
/// bayiler zaten katıldıkları gruplarda birbirleriyle konuşabiliyor.
class DealersScreen extends StatefulWidget {
  const DealersScreen({super.key});

  @override
  State<DealersScreen> createState() => _DealersScreenState();
}

class _DealersScreenState extends State<DealersScreen> {
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
            child: const Text('Engelle', style: TextStyle(color: AppColors.navy)),
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
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: const AppPageHeader(title: 'Bayiler'),
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
                    // Kullanıcı isteği: "son tasarım mükemmel, tüm sayfalara
                    // uygulayalım" — Ana Sayfa'daki büyük başlık dili burada
                    // da kullanılıyor.
                    itemCount: _dealers.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm, left: 2),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'Bayiler',
                                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.navy, letterSpacing: -0.8, height: 1.1),
                              ),
                              const SizedBox(width: 8),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text('${_dealers.length}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey.shade400)),
                              ),
                            ],
                          ),
                        );
                      }
                      final d = _dealers[index - 1];
                      final company = (d['company'] as String?) ?? '';
                      final initial = company.isNotEmpty ? company.characters.first.toUpperCase() : '?';
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.divider),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 3))],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
                          leading: d['avatarUrl'] != null
                              ? CircleAvatar(radius: 24, backgroundImage: NetworkImage(d['avatarUrl']))
                              : Container(
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
                                  child: Center(
                                    child: Text(initial, style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w800, fontSize: 17)),
                                  ),
                                ),
                          title: Text(company, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.navy, letterSpacing: -0.2)),
                          subtitle: Text('${d['firstName']} ${d['lastName']}', style: TextStyle(color: Colors.grey.shade500, fontSize: 12.5, fontWeight: FontWeight.w500)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton.filled(
                                onPressed: () => _startChat(d['id']),
                                icon: const Icon(Icons.chat_bubble_outline, size: 17),
                                style: IconButton.styleFrom(
                                  backgroundColor: AppColors.navy.withOpacity(0.08),
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
