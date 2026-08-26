import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import '../../core/storage/offline_documents_store.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/design_system.dart';
import '../../core/widgets/app_components.dart';

class OfflineDocumentsScreen extends StatefulWidget {
  const OfflineDocumentsScreen({super.key});

  @override
  State<OfflineDocumentsScreen> createState() => _OfflineDocumentsScreenState();
}

class _OfflineDocumentsScreenState extends State<OfflineDocumentsScreen> {
  final _store = OfflineDocumentsStore();
  List<Map<String, dynamic>> _documents = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final docs = await _store.listAll();
    setState(() {
      _documents = docs;
      _loading = false;
    });
  }

  Future<void> _open(Map<String, dynamic> doc) async {
    final path = doc['localPath'] as String;
    if (!await File(path).exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dosya cihazda bulunamadı, tekrar indirmeniz gerekebilir.')),
        );
      }
      return;
    }
    await OpenFilex.open(path);
  }

  Future<void> _remove(String documentId) async {
    final doc = await _store.get(documentId);
    if (doc != null) {
      final file = File(doc['localPath']);
      if (await file.exists()) await file.delete();
    }
    await _store.remove(documentId);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppPageHeader(
        title: 'İndirilenlerim',
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  '${_documents.length}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                ),
              ),
            ),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
        child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _documents.isEmpty
              ? RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    children: [
                      const SizedBox(height: 72),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                        child: StandardCard(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
                          child: const AppEmptyState(
                            icon: Icons.download_outlined,
                            title: 'Henüz indirilmiş bir doküman yok',
                            description: 'Bir dokümanı açıp "Çevrimdışı İndir" ile buraya ekleyebilirsiniz.',
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: _documents.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (context, index) {
                    final d = _documents[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.divider),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3))],
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [AppColors.navy.withValues(alpha: 0.10), AppColors.brand.withValues(alpha: 0.10)]),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.picture_as_pdf_outlined, color: AppColors.navy, size: 20),
                        ),
                        title: Text(d['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy, letterSpacing: -0.1)),
                        subtitle: Text('${d['brand']} / ${d['model']}', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                          onPressed: () => _remove(d['documentId']),
                          tooltip: 'İndirileni kaldır',
                        ),
                        onTap: () => _open(d),
                      ),
                    );
                  },
                ),
      ),
    );
  }
}
