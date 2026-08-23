import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/section_header.dart';
import '../../core/events/dealers_refresh_bus.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final Dio _dio = ApiClient().dio;
  List<dynamic> _blocked = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _dio.get('/users/blocked');
    setState(() {
      _blocked = res.data;
      _loading = false;
    });
  }

  Future<void> _unblock(String userId) async {
    await _dio.delete('/users/$userId/block');
    // Bayiler sekmesi, engeli kaldırılan bayiyi otomatik geri getirsin diye
    // sinyal gönderiyoruz — önceden sadece bu ekranın kendi listesi
    // güncelleniyordu, Bayiler sekmesi elle yenilenmeden bayatlamış kalıyordu.
    DealersRefreshBus.bump();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppBar(title: const Text('Engellenen Bayiler')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _blocked.isEmpty
              ? const EmptyState(icon: Icons.block, title: 'Engellediğiniz bir bayi yok')
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: _blocked.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (context, index) {
                    final u = _blocked[index];
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
                        leading: IconAvatar(
                          initial: (u['company'] as String? ?? '?').characters.first.toUpperCase(),
                          color: Colors.grey.shade600,
                        ),
                        title: Text(u['company'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('${u['firstName']} ${u['lastName']}'),
                        trailing: OutlinedButton(
                          onPressed: () => _unblock(u['id']),
                          child: const Text('Engeli Kaldır'),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
