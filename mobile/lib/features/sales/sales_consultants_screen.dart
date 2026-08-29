import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/design_system.dart';
import '../../core/widgets/app_components.dart';

/// Bayilerin satış danışmanlarına doğrudan (özel) mesaj gönderebildiği
/// ekran. Kullanıcı isteği: "call center gibi olsun ama satışçı olduğu
/// belli olsun" — üstte bir destek hattı afişi, her danışmanda net
/// "Satış Danışmanı" rozeti ve çağrı merkezi hissi veren durum
/// göstergesi kullanılıyor.
class SalesConsultantsScreen extends StatefulWidget {
  const SalesConsultantsScreen({super.key});

  @override
  State<SalesConsultantsScreen> createState() => _SalesConsultantsScreenState();
}

class _SalesConsultantsScreenState extends State<SalesConsultantsScreen> {
  final Dio _dio = ApiClient().dio;
  List<dynamic> _consultants = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await _dio.get('/users/sales-consultants');
    setState(() {
      _consultants = res.data;
      _loading = false;
    });
  }

  Future<void> _startChat(String consultantId) async {
    final res = await _dio.post('/chat/conversations/direct', data: {'otherUserId': consultantId});
    if (!mounted) return;
    context.push('/chat/${res.data['id']}');
  }

  Future<void> _call(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    try {
      await launchUrl(uri);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Arama başlatılamadı.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppPageHeader(title: 'Satış Danışmanına Sor'),
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
        child: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _consultants.isEmpty
                    ? AppEmptyState(
                        icon: Icons.support_agent_outlined,
                        title: 'Henüz satış danışmanı eklenmedi',
                        description: 'Admin, satış danışmanı hesabı ekleyince burada görünecek.',
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          children: [
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [AppColors.navy, AppColors.navyLight],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: AppColors.navy.withOpacity(0.22), blurRadius: 16, offset: const Offset(0, 6))],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(15)),
                              child: const Icon(Icons.headset_mic_outlined, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Satış Destek Hattı', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                                  SizedBox(height: 3),
                                  Text('Fiyat, ürün ve proje soruları için ekibimize ulaşın', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          '${_consultants.length} DANIŞMAN MEVCUT',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade400, letterSpacing: 0.6),
                        ),
                      ),
                      ..._consultants.map((c) {
                        final phone = c['phone'] as String?;
                        return Container(
                          margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 2))],
                          ),
                          child: Row(
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: AppColors.navy.withOpacity(0.08),
                                    child: const Icon(Icons.headset_mic_outlined, color: AppColors.navy, size: 22),
                                  ),
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade500,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${c['firstName']} ${c['lastName']}',
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: AppColors.navy),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.brand.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Text(
                                        'SATIŞ DANIŞMANI',
                                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.brand, letterSpacing: 0.4),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (phone != null && phone.isNotEmpty)
                                IconButton.filled(
                                  onPressed: () => _call(phone),
                                  icon: const Icon(Icons.call_outlined, size: 17),
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.green.withOpacity(0.1),
                                    foregroundColor: Colors.green.shade700,
                                  ),
                                  tooltip: 'Ara',
                                ),
                              const SizedBox(width: 6),
                              IconButton.filled(
                                onPressed: () => _startChat(c['id']),
                                icon: const Icon(Icons.chat_bubble_outline, size: 17),
                                style: IconButton.styleFrom(
                                  backgroundColor: AppColors.brand.withOpacity(0.1),
                                  foregroundColor: AppColors.brand,
                                ),
                                tooltip: 'Mesaj gönder',
                              ),
                            ],
                          ),
                        );
                      }),
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
