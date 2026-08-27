import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// İndirilen dokümanların yerel kaydı (manifest). Dosyaların kendisi
/// `path_provider`'ın kalıcı (temp değil) uygulama klasöründe tutulur,
/// burada sadece "hangi doküman nerede, ne zaman indirildi" bilgisi saklanır.
class OfflineDocumentsStore {
  static const _key = 'offline_documents_v1';

  Future<Map<String, dynamic>> _readManifest() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> _writeManifest(Map<String, dynamic> manifest) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(manifest));
  }

  Future<Map<String, dynamic>?> get(String documentId) async {
    final manifest = await _readManifest();
    return manifest[documentId] as Map<String, dynamic>?;
  }

  Future<void> save({
    required String documentId,
    required String title,
    required String brand,
    required String model,
    required String localPath,
  }) async {
    final manifest = await _readManifest();
    manifest[documentId] = {
      'documentId': documentId,
      'title': title,
      'brand': brand,
      'model': model,
      'localPath': localPath,
      'downloadedAt': DateTime.now().toIso8601String(),
    };
    await _writeManifest(manifest);
  }

  Future<void> remove(String documentId) async {
    final manifest = await _readManifest();
    manifest.remove(documentId);
    await _writeManifest(manifest);
  }

  Future<List<Map<String, dynamic>>> listAll() async {
    final manifest = await _readManifest();
    return manifest.values.cast<Map<String, dynamic>>().toList()..sort(
      (a, b) =>
          (b['downloadedAt'] as String).compareTo(a['downloadedAt'] as String),
    );
  }
}
